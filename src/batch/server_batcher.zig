// NenDB Server-Side Batcher
// Processes batches with LSM-style organization for high durability
// Inspired by TigerBeetle's server-side batch processing

const std = @import("std");
const batch = @import("batch_processor.zig");
const wal = @import("../memory/wal.zig");

// Server-side batch configuration
pub const ServerBatchConfig = struct {
    max_batch_size: u32 = 8192,
    lsm_levels: u8 = 4, // Number of LSM tree levels
    level_size_multiplier: u32 = 10, // Each level is 10x larger
    compaction_threshold: u32 = 1000, // Operations before compaction
    enable_parallel_processing: bool = true,
    enable_write_optimization: bool = true,
};

// LSM tree level for organizing batches
pub const LSMLevel = struct {
    const Self = @This();
    
    level_id: u8,
    max_size: u32,
    current_size: u32,
    batches: std.ArrayList(batch.Batch),
    
    pub fn init(allocator: std.mem.Allocator, level: u8, max_size: u32) Self {
        return Self{
            .level_id = level,
            .max_size = max_size,
            .current_size = 0,
            .batches = std.ArrayList(batch.Batch).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.batches.deinit();
    }
    
    pub fn addBatch(self: *Self, new_batch: batch.Batch) !bool {
        if (self.current_size + new_batch.size() > self.max_size) {
            return false; // Level is full
        }
        
        try self.batches.append(new_batch);
        self.current_size += new_batch.size();
        return true;
    }
    
    pub fn isFull(self: Self) bool {
        return self.current_size >= self.max_size;
    }
    
    pub fn clear(self: *Self) void {
        self.batches.clearRetainingCapacity();
        self.current_size = 0;
    }
};

// Server-side batch processor with LSM organization
pub const ServerBatcher = struct {
    const Self = @This();
    
    config: ServerBatchConfig,
    allocator: std.mem.Allocator,
    
    // LSM tree levels for organizing batches
    lsm_levels: [4]LSMLevel,
    
    // Current active batch for incoming operations
    active_batch: batch.Batch,
    
    // Statistics and monitoring
    stats: ServerBatchStats,
    
    // WAL for durability
    wal_writer: *wal.WAL,
    
    pub fn init(allocator: std.mem.Allocator, config: ServerBatchConfig, wal_writer: *wal.WAL) !Self {
        var lsm_levels: [4]LSMLevel = undefined;
        
        // Initialize LSM levels with exponentially increasing sizes
        for (0..4) |i| {
            const level_size = config.max_batch_size * std.math.pow(u32, config.level_size_multiplier, @intCast(i));
            lsm_levels[i] = LSMLevel.init(allocator, @intCast(i), level_size);
        }
        
        return Self{
            .config = config,
            .allocator = allocator,
            .lsm_levels = lsm_levels,
            .active_batch = batch.Batch.init(),
            .stats = ServerBatchStats.init(),
            .wal_writer = wal_writer,
        };
    }
    
    pub fn deinit(self: *Self) void {
        for (self.lsm_levels) |*level| {
            level.deinit();
        }
    }
    
    // Process incoming batch from client
    pub fn processClientBatch(self: *Self, client_batch: batch.Batch) !ServerBatchResult {
        const start_time = std.time.nanoTimestamp();
        
        // Validate batch
        if (client_batch.size() > self.config.max_batch_size) {
            return ServerBatchResult{
                .success = false,
                .error = error.BatchTooLarge,
                .processed = 0,
            };
        }
        
        // Write to WAL first (durability)
        try self.wal_writer.append_batch(client_batch.messages[0..client_batch.count]);
        
        // Process batch serially (like TigerBeetle)
        const result = try self.processBatchSerially(client_batch);
        
        // Add to LSM tree
        try self.addToLSMTree(client_batch);
        
        // Check if compaction is needed
        if (self.shouldCompact()) {
            try self.compactLSMTree();
        }
        
        const end_time = std.time.nanoTimestamp();
        const processing_time = @as(u64, @intCast(end_time - start_time));
        
        // Update statistics
        self.stats.batches_processed += 1;
        self.stats.operations_processed += result.processed;
        self.stats.total_processing_time += processing_time;
        
        return ServerBatchResult{
            .success = result.success,
            .processed = result.processed,
            .processing_time = processing_time,
        };
    }
    
    // Process batch serially (TigerBeetle approach)
    fn processBatchSerially(self: *Self, client_batch: batch.Batch) !batch.BatchResult {
        var processor = batch.BatchProcessor.init(
            &self.node_pool,
            &self.edge_pool,
            self.wal_writer,
        );
        
        return try processor.processBatch(&client_batch);
    }
    
    // Add batch to LSM tree
    fn addToLSMTree(self: *Self, client_batch: batch.Batch) !void {
        // Try to add to level 0 first
        if (try self.lsm_levels[0].addBatch(client_batch)) {
            self.stats.batches_added_to_level[0] += 1;
            return;
        }
        
        // Level 0 is full, try to merge and promote
        try self.mergeAndPromote(0);
        
        // Try again after merge
        if (try self.lsm_levels[0].addBatch(client_batch)) {
            self.stats.batches_added_to_level[0] += 1;
        } else {
            return error.LSMTreeFull;
        }
    }
    
    // Merge and promote batches between LSM levels
    fn mergeAndPromote(self: *Self, level: u8) !void {
        if (level >= self.lsm_levels.len - 1) {
            return error.MaxLevelReached;
        }
        
        const current_level = &self.lsm_levels[level];
        const next_level = &self.lsm_levels[level + 1];
        
        if (!current_level.isFull()) {
            return; // No need to merge
        }
        
        // Merge all batches from current level
        var merged_batch = batch.Batch.init();
        
        for (current_level.batches.items) |level_batch| {
            for (level_batch.messages[0..level_batch.count]) |msg| {
                if (merged_batch.isFull()) break;
                
                // Add message to merged batch
                merged_batch.messages[merged_batch.count] = msg;
                merged_batch.count += 1;
            }
        }
        
        // Try to add merged batch to next level
        if (try next_level.addBatch(merged_batch)) {
            // Clear current level
            current_level.clear();
            self.stats.merges_performed += 1;
        } else {
            // Next level is also full, recursively merge
            try self.mergeAndPromote(level + 1);
            
            // Try again after recursive merge
            if (try next_level.addBatch(merged_batch)) {
                current_level.clear();
                self.stats.merges_performed += 1;
            } else {
                return error.LSMTreeFull;
            }
        }
    }
    
    // Check if compaction is needed
    fn shouldCompact(self: *Self) bool {
        return self.stats.operations_processed >= self.config.compaction_threshold;
    }
    
    // Compact LSM tree to optimize read performance
    fn compactLSMTree(self: *Self) !void {
        const start_time = std.time.nanoTimestamp();
        
        // Compact from highest level down
        var level: i32 = @intCast(self.lsm_levels.len - 1);
        while (level >= 0) : (level -= 1) {
            const level_idx = @intCast(level);
            const current_level = &self.lsm_levels[level_idx];
            
            if (current_level.batches.items.len > 1) {
                try self.compactLevel(level_idx);
            }
        }
        
        const end_time = std.time.nanoTimestamp();
        const compaction_time = @as(u64, @intCast(end_time - start_time));
        
        self.stats.compactions_performed += 1;
        self.stats.total_compaction_time += compaction_time;
        self.stats.operations_processed = 0; // Reset counter
    }
    
    // Compact a specific LSM level
    fn compactLevel(self: *Self, level: u8) !void {
        const current_level = &self.lsm_levels[level];
        
        // Sort batches by timestamp for efficient merging
        std.sort.insertion(batch.Batch, current_level.batches.items, {}, struct {
            fn lessThan(_: void, a: batch.Batch, b: batch.Batch) bool {
                if (a.count == 0) return false;
                if (b.count == 0) return true;
                return a.messages[0].timestamp < b.messages[0].timestamp;
            }
        }.lessThan);
        
        // Merge adjacent batches
        var i: usize = 0;
        while (i < current_level.batches.items.len - 1) {
            const batch1 = current_level.batches.items[i];
            const batch2 = current_level.batches.items[i + 1];
            
            var merged = batch.Batch.init();
            
            // Merge batch1 and batch2 into merged
            try self.mergeBatches(batch1, batch2, &merged);
            
            // Replace batch1 with merged, remove batch2
            current_level.batches.items[i] = merged;
            _ = current_level.batches.orderedRemove(i + 1);
            
            // Don't increment i, check the same position again
        }
    }
    
    // Merge two batches into a single batch
    fn mergeBatches(self: *Self, batch1: batch.Batch, batch2: batch.Batch, merged: *batch.Batch) !void {
        var i1: usize = 0;
        var i2: usize = 0;
        
        while (i1 < batch1.count and i2 < batch2.count and !merged.isFull()) {
            const msg1 = batch1.messages[i1];
            const msg2 = batch2.messages[i2];
            
            // Choose message with earlier timestamp
            if (msg1.timestamp <= msg2.timestamp) {
                merged.messages[merged.count] = msg1;
                merged.count += 1;
                i1 += 1;
            } else {
                merged.messages[merged.count] = msg2;
                merged.count += 1;
                i2 += 1;
            }
        }
        
        // Add remaining messages from batch1
        while (i1 < batch1.count and !merged.isFull()) {
            merged.messages[merged.count] = batch1.messages[i1];
            merged.count += 1;
            i1 += 1;
        }
        
        // Add remaining messages from batch2
        while (i2 < batch2.count and !merged.isFull()) {
            merged.messages[merged.count] = batch2.messages[i2];
            merged.count += 1;
            i2 += 1;
        }
    }
    
    // Get server batch statistics
    pub fn getStats(self: *const Self) ServerBatchStats {
        return self.stats;
    }
    
    // Get LSM tree statistics
    pub fn getLSMStats(self: *const Self) LSMStats {
        var lsm_stats = LSMStats.init();
        
        for (self.lsm_levels, 0..) |level, i| {
            lsm_stats.level_sizes[i] = level.current_size;
            lsm_stats.level_batch_counts[i] = @intCast(level.batches.items.len);
        }
        
        return lsm_stats;
    }
};

// Server batch result
pub const ServerBatchResult = struct {
    success: bool,
    processed: u32 = 0,
    processing_time: u64 = 0,
    error: ?anyerror = null,
};

// Server batch statistics
pub const ServerBatchStats = struct {
    batches_processed: u64 = 0,
    operations_processed: u64 = 0,
    total_processing_time: u64 = 0,
    merges_performed: u64 = 0,
    compactions_performed: u64 = 0,
    total_compaction_time: u64 = 0,
    batches_added_to_level: [4]u64 = .{0} ** 4,
    
    pub fn init() ServerBatchStats {
        return ServerBatchStats{};
    }
    
    pub fn getAverageProcessingTime(self: ServerBatchStats) f64 {
        if (self.batches_processed == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_processing_time)) / @as(f64, @floatFromInt(self.batches_processed));
    }
    
    pub fn getAverageBatchSize(self: ServerBatchStats) f64 {
        if (self.batches_processed == 0) return 0.0;
        return @as(f64, @floatFromInt(self.operations_processed)) / @as(f64, @floatFromInt(self.batches_processed));
    }
    
    pub fn getCompactionFrequency(self: ServerBatchStats) f64 {
        if (self.batches_processed == 0) return 0.0;
        return @as(f64, @floatFromInt(self.compactions_performed)) / @as(f64, @floatFromInt(self.batches_processed));
    }
};

// LSM tree statistics
pub const LSMStats = struct {
    level_sizes: [4]u32 = .{0} ** 4,
    level_batch_counts: [4]u32 = .{0} ** 4,
    
    pub fn init() LSMStats {
        return LSMStats{};
    }
    
    pub fn getTotalSize(self: LSMStats) u32 {
        var total: u32 = 0;
        for (self.level_sizes) |size| {
            total += size;
        }
        return total;
    }
    
    pub fn getTotalBatches(self: LSMStats) u32 {
        var total: u32 = 0;
        for (self.level_batch_counts) |count| {
            total += count;
        }
        return total;
    }
};
