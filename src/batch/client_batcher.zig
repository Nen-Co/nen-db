// NenDB Client-Side Batcher
// Automatically batches operations to reduce network overhead
// Inspired by TigerBeetle's client-side batching approach

const std = @import("std");
const batch = @import("batch_processor.zig");

// Client-side batch configuration
pub const ClientBatchConfig = struct {
    max_batch_size: u32 = 8192,
    max_batch_wait_ms: u32 = 10, // Maximum time to wait for batch to fill
    auto_flush_threshold: u32 = 100, // Auto-flush when this many operations are queued
    enable_homogeneous_batching: bool = true, // Group similar operations
    enable_adaptive_batching: bool = true, // Adjust batch size based on load
};

// Operation types for homogeneous batching
pub const OperationType = enum(u8) {
    create_node = 1,
    create_edge = 2,
    update_node = 3,
    delete_node = 4,
    delete_edge = 5,
    set_embedding = 6,
    query = 7,
};

// Queued operation for client-side batching
pub const QueuedOperation = struct {
    type: OperationType,
    timestamp: u64,
    data: []const u8,
    priority: u8,
    
    pub fn init(op_type: OperationType, op_data: []const u8, op_priority: u8) QueuedOperation {
        return QueuedOperation{
            .type = op_type,
            .timestamp = @as(u64, @intCast(std.time.nanoTimestamp())),
            .data = op_data,
            .priority = op_priority,
        };
    }
};

// Client-side batcher that automatically groups operations
pub const ClientBatcher = struct {
    const Self = @This();
    
    config: ClientBatchConfig,
    
    // Operation queues for different types (homogeneous batching)
    node_operations: std.ArrayList(QueuedOperation),
    edge_operations: std.ArrayList(QueuedOperation),
    vector_operations: std.ArrayList(QueuedOperation),
    query_operations: std.ArrayList(QueuedOperation),
    
    // Batch statistics for adaptive batching
    stats: ClientBatchStats,
    
    // Timing for auto-flush
    last_flush_time: u64,
    
    pub fn init(allocator: std.mem.Allocator, config: ClientBatchConfig) !Self {
        return Self{
            .config = config,
            .node_operations = std.ArrayList(QueuedOperation).init(allocator),
            .edge_operations = std.ArrayList(QueuedOperation).init(allocator),
            .vector_operations = std.ArrayList(QueuedOperation).init(allocator),
            .query_operations = std.ArrayList(QueuedOperation).init(allocator),
            .stats = ClientBatchStats.init(),
            .last_flush_time = @as(u64, @intCast(std.time.nanoTimestamp())),
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.node_operations.deinit();
        self.edge_operations.deinit();
        self.vector_operations.deinit();
        self.query_operations.deinit();
    }
    
    // Add node creation operation to batch
    pub fn addCreateNode(self: *Self, node_data: []const u8, priority: u8) !void {
        const op = QueuedOperation.init(.create_node, node_data, priority);
        try self.node_operations.append(op);
        self.stats.operations_queued += 1;
        
        // Check if we should auto-flush
        try self.checkAutoFlush();
    }
    
    // Add edge creation operation to batch
    pub fn addCreateEdge(self: *Self, edge_data: []const u8, priority: u8) !void {
        const op = QueuedOperation.init(.create_edge, edge_data, priority);
        try self.edge_operations.append(op);
        self.stats.operations_queued += 1;
        
        try self.checkAutoFlush();
    }
    
    // Add vector embedding operation to batch
    pub fn addSetEmbedding(self: *Self, embedding_data: []const u8, priority: u8) !void {
        const op = QueuedOperation.init(.set_embedding, embedding_data, priority);
        try self.vector_operations.append(op);
        self.stats.operations_queued += 1;
        
        try self.checkAutoFlush();
    }
    
    // Add query operation to batch
    pub fn addQuery(self: *Self, query_data: []const u8, priority: u8) !void {
        const op = QueuedOperation.init(.query, query_data, priority);
        try self.query_operations.append(op);
        self.stats.operations_queued += 1;
        
        try self.checkAutoFlush();
    }
    
    // Check if we should auto-flush based on config
    fn checkAutoFlush(self: *Self) !void {
        const current_time = @as(u64, @intCast(std.time.nanoTimestamp()));
        const time_since_flush = (current_time - self.last_flush_time) / 1_000_000; // Convert to ms
        
        const should_flush = 
            self.getTotalQueuedOperations() >= self.config.auto_flush_threshold or
            time_since_flush >= self.config.max_batch_wait_ms;
        
        if (should_flush) {
            try self.flush();
        }
    }
    
    // Get total number of queued operations
    fn getTotalQueuedOperations(self: Self) u32 {
        return @intCast(self.node_operations.items.len + 
                       self.edge_operations.items.len + 
                       self.vector_operations.items.len + 
                       self.query_operations.items.len);
    }
    
    // Flush all queued operations to server
    pub fn flush(self: *Self) !void {
        const start_time = std.time.nanoTimestamp();
        
        // Create homogeneous batches for each operation type
        if (self.node_operations.items.len > 0) {
            try self.flushNodeOperations();
        }
        
        if (self.edge_operations.items.len > 0) {
            try self.flushEdgeOperations();
        }
        
        if (self.vector_operations.items.len > 0) {
            try self.flushVectorOperations();
        }
        
        if (self.query_operations.items.len > 0) {
            try self.flushQueryOperations();
        }
        
        const end_time = std.time.nanoTimestamp();
        const flush_duration = @as(u64, @intCast(end_time - start_time));
        
        // Update statistics
        self.stats.flushes_performed += 1;
        self.stats.total_flush_time += flush_duration;
        self.last_flush_time = @as(u64, @intCast(std.time.nanoTimestamp()));
        
        // Adaptive batching: adjust batch size based on performance
        if (self.config.enable_adaptive_batching) {
            try self.adjustBatchSize(flush_duration);
        }
    }
    
    // Flush node operations as homogeneous batch
    fn flushNodeOperations(self: *Self) !void {
        var new_batch = batch.Batch.init();
        var flushed_count: u32 = 0;
        
        for (self.node_operations.items) |op| {
            if (new_batch.isFull()) break;
            
            try new_batch.addCreateNode(std.mem.bytesAsValue(batch.pool.Node, op.data).*);
            flushed_count += 1;
        }
        
        // Execute batch
        // TODO: Send to server via network
        // new_batch will be sent to server
        
        // Remove flushed operations
        self.node_operations.shrinkRetainingCapacity(self.node_operations.items.len - flushed_count);
        self.stats.operations_flushed += flushed_count;
    }
    
    // Flush edge operations as homogeneous batch
    fn flushEdgeOperations(self: *Self) !void {
        var new_batch = batch.Batch.init();
        var flushed_count: u32 = 0;
        
        for (self.edge_operations.items) |op| {
            if (new_batch.isFull()) break;
            
            try new_batch.addCreateEdge(std.mem.bytesAsValue(batch.pool.Edge, op.data).*);
            flushed_count += 1;
        }
        
        // Execute batch
        // TODO: Send to server via network
        // new_batch will be sent to server
        
        // Remove flushed operations
        self.edge_operations.shrinkRetainingCapacity(self.edge_operations.items.len - flushed_count);
        self.stats.operations_flushed += flushed_count;
    }
    
    // Flush vector operations as homogeneous batch
    fn flushVectorOperations(self: *Self) !void {
        var new_batch = batch.Batch.init();
        var flushed_count: u32 = 0;
        
        for (self.vector_operations.items) |op| {
            if (new_batch.isFull()) break;
            
            // Parse embedding data (node_id + vector)
            const node_id = std.mem.readIntLittle(u64, op.data[0..8]);
            const vector = std.mem.bytesAsValue([256]f32, op.data[8..264]);
            try new_batch.addSetEmbedding(node_id, vector.*);
            flushed_count += 1;
        }
        
        // Execute batch
        // TODO: Send to server via network
        // new_batch will be sent to server
        
        // Remove flushed operations
        self.vector_operations.shrinkRetainingCapacity(self.vector_operations.items.len - flushed_count);
        self.stats.operations_flushed += flushed_count;
    }
    
    // Flush query operations as homogeneous batch
    fn flushQueryOperations(self: *Self) !void {
        // Queries might be handled differently - could be sent individually
        // or batched depending on the query type
        var flushed_count: u32 = 0;
        
        for (self.query_operations.items) |op| {
            // TODO: Send query to server
            _ = op;
            flushed_count += 1;
        }
        
        // Remove flushed operations
        self.query_operations.shrinkRetainingCapacity(self.query_operations.items.len - flushed_count);
        self.stats.operations_flushed += flushed_count;
    }
    
    // Adaptive batching: adjust batch size based on performance
    fn adjustBatchSize(self: *Self, flush_duration: u64) !void {
        _ = self.stats.total_flush_time / @max(self.stats.flushes_performed, 1);
        const target_flush_time = 1_000_000; // 1ms target
        
        if (flush_duration > target_flush_time * 2) {
            // Flush is taking too long, reduce batch size
            self.config.auto_flush_threshold = @max(10, self.config.auto_flush_threshold / 2);
            self.stats.batch_size_adjustments += 1;
        } else if (flush_duration < target_flush_time / 2) {
            // Flush is very fast, increase batch size
            self.config.auto_flush_threshold = @min(8192, self.config.auto_flush_threshold * 2);
            self.stats.batch_size_adjustments += 1;
        }
    }
    
    // Get current batch statistics
    pub fn getStats(self: *const Self) ClientBatchStats {
        return self.stats;
    }
    
    // Get current configuration
    pub fn getConfig(self: *const Self) ClientBatchConfig {
        return self.config;
    }
    
    // Update configuration
    pub fn updateConfig(self: *Self, new_config: ClientBatchConfig) void {
        self.config = new_config;
    }
};

// Client batch statistics
pub const ClientBatchStats = struct {
    operations_queued: u64 = 0,
    operations_flushed: u64 = 0,
    flushes_performed: u64 = 0,
    total_flush_time: u64 = 0,
    batch_size_adjustments: u32 = 0,
    
    pub fn init() ClientBatchStats {
        return ClientBatchStats{};
    }
    
    pub fn getAverageFlushTime(self: ClientBatchStats) f64 {
        if (self.flushes_performed == 0) return 0.0;
        return @as(f64, @floatFromInt(self.total_flush_time)) / @as(f64, @floatFromInt(self.flushes_performed));
    }
    
    pub fn getAverageBatchSize(self: ClientBatchStats) f64 {
        if (self.flushes_performed == 0) return 0.0;
        return @as(f64, @floatFromInt(self.operations_flushed)) / @as(f64, @floatFromInt(self.flushes_performed));
    }
    
    pub fn getQueueUtilization(self: ClientBatchStats) f64 {
        if (self.operations_queued == 0) return 0.0;
        return @as(f64, @floatFromInt(self.operations_flushed)) / @as(f64, @floatFromInt(self.operations_queued));
    }
};
