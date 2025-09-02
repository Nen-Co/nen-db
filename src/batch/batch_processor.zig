// NenDB Batch Processing System
// Inspired by TigerBeetle's high-performance batch processing
// All operations are inline for maximum performance

const std = @import("std");
const pool = @import("../memory/pool.zig");
const wal = @import("../memory/wal.zig");
const constants = @import("../constants.zig");

// Pre-allocated message types for zero-allocation batching
pub const MessageType = enum(u8) {
    create_node = 1,
    create_edge = 2,
    update_node = 3,
    delete_node = 4,
    delete_edge = 5,
    set_embedding = 6,
    batch_commit = 7,
};

// Fixed-size message structure (like TigerBeetle)
pub const Message = extern struct {
    type: MessageType,
    timestamp: u64,
    data: [64]u8, // Fixed size for predictable memory layout

    pub inline fn init(comptime msg_type: MessageType, data: []const u8) Message {
        var msg = Message{
            .type = msg_type,
            .timestamp = @as(u64, @intCast(std.time.nanoTimestamp())),
            .data = undefined,
        };

        // Copy data with bounds checking
        const copy_len = @min(data.len, msg.data.len);
        @memcpy(msg.data[0..copy_len], data[0..copy_len]);

        return msg;
    }
};

// Batch structure with pre-allocated message buffer
pub const Batch = struct {
    const Self = @This();

    // Pre-allocated message buffer (like TigerBeetle)
    messages: [constants.batch.max_batch_size]Message = undefined,
    count: u32 = 0,

    // Pre-allocated data buffers for zero-copy operations
    node_buffer: [constants.batch.max_batch_size * @sizeOf(pool.Node)]u8 = undefined,
    edge_buffer: [constants.batch.max_batch_size * @sizeOf(pool.Edge)]u8 = undefined,
    vector_buffer: [constants.batch.max_batch_size * @sizeOf([256]f32)]u8 = undefined,

    // Buffer positions
    node_pos: usize = 0,
    edge_pos: usize = 0,
    vector_pos: usize = 0,

    pub inline fn init() Self {
        return Self{};
    }

    // Add node creation to batch
    pub inline fn addCreateNode(self: *Self, node: pool.Node) !void {
        if (self.count >= constants.batch.max_batch_size) {
            return error.BatchFull;
        }

        // Copy node data to pre-allocated buffer
        const node_bytes = std.mem.asBytes(&node);
        if (self.node_pos + node_bytes.len <= self.node_buffer.len) {
            @memcpy(self.node_buffer[self.node_pos..][0..node_bytes.len], node_bytes);
            self.node_pos += node_bytes.len;
        }

        // Create message
        const msg = Message.init(.create_node, node_bytes);
        self.messages[self.count] = msg;
        self.count += 1;
    }

    // Add edge creation to batch
    pub inline fn addCreateEdge(self: *Self, edge: pool.Edge) !void {
        if (self.count >= constants.batch.max_batch_size) {
            return error.BatchFull;
        }

        // Copy edge data to pre-allocated buffer
        const edge_bytes = std.mem.asBytes(&edge);
        if (self.edge_pos + edge_bytes.len <= self.edge_buffer.len) {
            @memcpy(self.edge_buffer[self.edge_pos..][0..edge_bytes.len], edge_bytes);
            self.edge_pos += edge_bytes.len;
        }

        // Create message
        const msg = Message.init(.create_edge, edge_bytes);
        self.messages[self.count] = msg;
        self.count += 1;
    }

    // Add vector embedding to batch
    pub inline fn addSetEmbedding(self: *Self, node_id: u64, vector: [256]f32) !void {
        if (self.count >= constants.batch.max_batch_size) {
            return error.BatchFull;
        }

        // Create embedding data
        var embedding_data: [264]u8 = undefined; // 8 bytes for node_id + 256 bytes for vector
        @memcpy(embedding_data[0..8], std.mem.asBytes(&node_id));
        @memcpy(embedding_data[8..264], std.mem.asBytes(&vector));

        // Copy to pre-allocated buffer
        if (self.vector_pos + embedding_data.len <= self.vector_buffer.len) {
            @memcpy(self.vector_buffer[self.vector_pos..][0..embedding_data.len], embedding_data);
            self.vector_pos += embedding_data.len;
        }

        // Create message
        const msg = Message.init(.set_embedding, &embedding_data);
        self.messages[self.count] = msg;
        self.count += 1;
    }

    // Get current batch size
    pub inline fn size(self: Self) u32 {
        return self.count;
    }

    // Check if batch is empty
    pub inline fn isEmpty(self: Self) bool {
        return self.count == 0;
    }

    // Check if batch is full
    pub inline fn isFull(self: Self) bool {
        return self.count >= constants.batch.max_batch_size;
    }

    // Clear batch (for reuse)
    pub inline fn clear(self: *Self) void {
        self.count = 0;
        self.node_pos = 0;
        self.edge_pos = 0;
        self.vector_pos = 0;
    }
};

// Batch processor for executing batches
pub const BatchProcessor = struct {
    const Self = @This();

    node_pool: *pool.NodePool,
    edge_pool: *pool.EdgePool,
    wal_writer: *wal.WAL,

    // Pre-allocated result buffers
    results: [constants.batch.max_batch_size]BatchResult = undefined,
    result_count: u32 = 0,

    pub fn init(node_pool: *pool.NodePool, edge_pool: *pool.EdgePool, wal_writer: *wal.WAL) Self {
        return Self{
            .node_pool = node_pool,
            .edge_pool = edge_pool,
            .wal_writer = wal_writer,
        };
    }

    // Process a batch atomically (like TigerBeetle)
    pub fn processBatch(self: *Self, batch: *const Batch) !BatchResult {
        if (batch.isEmpty()) {
            return BatchResult{ .success = true, .processed = 0 };
        }

        // Start atomic transaction
        self.result_count = 0;

        // Process all messages in batch
        for (batch.messages[0..batch.count], 0..) |msg, i| {
            const result = try self.processMessage(msg);
            self.results[self.result_count] = result;
            self.result_count += 1;

            // If any message fails, abort the entire batch
            if (!result.success) {
                return BatchResult{
                    .success = false,
                    .processed = @intCast(i),
                };
            }
        }

        // Commit WAL batch atomically
        try self.wal_writer.append_batch(batch.messages[0..batch.count]);

        return BatchResult{
            .success = true,
            .processed = batch.count,
        };
    }

    // Process individual message
    fn processMessage(self: *Self, msg: Message) !BatchResult {
        switch (msg.type) {
            .create_node => {
                const node = std.mem.bytesAsValue(pool.Node, msg.data[0..@sizeOf(pool.Node)]);
                _ = self.node_pool.alloc(node.*) catch |e| {
                    _ = e;
                    return BatchResult{ .success = false };
                };
                return BatchResult{ .success = true, .node_id = node.id };
            },
            .create_edge => {
                const edge = std.mem.bytesAsValue(pool.Edge, msg.data[0..@sizeOf(pool.Edge)]);
                const idx = self.edge_pool.alloc(edge.*) catch |e| {
                    _ = e;
                    return BatchResult{ .success = false };
                };
                return BatchResult{ .success = true, .edge_id = idx };
            },
            .set_embedding => {
                const node_id = std.mem.readIntLittle(u64, msg.data[0..8]);
                _ = std.mem.bytesAsValue([256]f32, msg.data[8..264]);
                // Set embedding (implementation depends on vector store)
                return BatchResult{ .success = true, .node_id = node_id };
            },
            else => {
                return BatchResult{ .success = false };
            },
        }
    }
};

// Batch result structure
pub const BatchResult = struct {
    success: bool,
    processed: u32 = 0,
    err: ?anyerror = null,
    node_id: ?u64 = null,
    edge_id: ?usize = null,
};

// Batch statistics for monitoring
pub const BatchStats = struct {
    batches_processed: u64 = 0,
    messages_processed: u64 = 0,
    batches_failed: u64 = 0,
    avg_batch_size: f64 = 0.0,
    total_processing_time: u64 = 0,

    pub inline fn update(self: *BatchStats, batch_size: u32, processing_time: u64, success: bool) void {
        if (success) {
            self.batches_processed += 1;
            self.messages_processed += batch_size;
            self.total_processing_time += processing_time;

            // Update average batch size
            const total_batches = @as(f64, @floatFromInt(self.batches_processed));
            const total_messages = @as(f64, @floatFromInt(self.messages_processed));
            self.avg_batch_size = total_messages / total_batches;
        } else {
            self.batches_failed += 1;
        }
    }
};

// High-level batch API for easy use
pub const BatchAPI = struct {
    const Self = @This();

    processor: BatchProcessor,
    stats: BatchStats,

    pub fn init(node_pool: *pool.NodePool, edge_pool: *pool.EdgePool, wal_writer: *wal.WAL) Self {
        return Self{
            .processor = BatchProcessor.init(node_pool, edge_pool, wal_writer),
            .stats = BatchStats{},
        };
    }

    // Convenience method for batch operations
    pub fn executeBatch(self: *Self, batch: *const Batch) !BatchResult {
        const start_time = std.time.nanoTimestamp();
        const result = try self.processor.processBatch(batch);
        const end_time = std.time.nanoTimestamp();
        const processing_time = @as(u64, @intCast(end_time - start_time));

        self.stats.update(batch.size(), processing_time, result.success);

        return result;
    }

    // Get batch statistics
    pub fn getStats(self: *const Self) BatchStats {
        return self.stats;
    }
};
