// NenDB Batch Processor - TigerBeetle Style
// Implements high-performance batch processing with static memory allocation

const std = @import("std");
const assert = std.debug.assert;
const constants = @import("constants.zig");
const layout = @import("../memory/layout.zig");
const simd = @import("../memory/simd.zig");

// =============================================================================
// Batch Processing Configuration (TigerBeetle Style)
// =============================================================================

pub const BatchConfig = struct {
    max_batch_size: u32 = constants.batch.max_batch_size,
    batch_timeout_ms: u32 = constants.batch.batch_timeout_ms,
    auto_commit_threshold: u32 = constants.batch.auto_commit_threshold,
    enable_zero_copy: bool = constants.batch.enable_zero_copy,
    enable_atomic_commit: bool = constants.batch.enable_atomic_commit,
    enable_batch_statistics: bool = constants.batch.enable_batch_statistics,
};

// =============================================================================
// Message Types for Batch Processing
// =============================================================================

pub const MessageType = enum(u8) {
    insert_node = 1,
    insert_edge = 2,
    delete_node = 3,
    delete_edge = 4,
    update_property = 5,
    insert_vector = 6,
    batch_commit = 7,
};

pub const NodeMessage = struct {
    message_type: MessageType = .insert_node,
    id: u64,
    kind: u8,
    properties_size: u16,
    // Properties follow inline (zero-copy)

    pub const SIZE = 8 + 1 + 2; // 11 bytes header

    pub inline fn serialize(self: *const NodeMessage, buffer: []u8) !usize {
        assert(buffer.len >= SIZE);

        var offset: usize = 0;
        buffer[offset] = @intFromEnum(self.message_type);
        offset += 1;

        std.mem.writeInt(u64, buffer[offset..][0..8], self.id, .little);
        offset += 8;

        buffer[offset] = self.kind;
        offset += 1;

        std.mem.writeInt(u16, buffer[offset..][0..2], self.properties_size, .little);
        offset += 2;

        return offset;
    }

    pub inline fn deserialize(buffer: []const u8) !NodeMessage {
        assert(buffer.len >= SIZE);

        var offset: usize = 0;
        const message_type = @as(MessageType, @enumFromInt(buffer[offset]));
        offset += 1;

        const id = std.mem.readInt(u64, buffer[offset..][0..8], .little);
        offset += 8;

        const kind = buffer[offset];
        offset += 1;

        const properties_size = std.mem.readInt(u16, buffer[offset..][0..2], .little);
        offset += 2;

        return NodeMessage{
            .message_type = message_type,
            .id = id,
            .kind = kind,
            .properties_size = properties_size,
        };
    }
};

pub const EdgeMessage = struct {
    message_type: MessageType = .insert_edge,
    from: u64,
    to: u64,
    label: u16,
    properties_size: u16,

    pub const SIZE = 8 + 8 + 2 + 2; // 20 bytes header

    pub inline fn serialize(self: *const EdgeMessage, buffer: []u8) !usize {
        assert(buffer.len >= SIZE);

        var offset: usize = 0;
        buffer[offset] = @intFromEnum(self.message_type);
        offset += 1;

        std.mem.writeInt(u64, buffer[offset..][0..8], self.from, .little);
        offset += 8;

        std.mem.writeInt(u64, buffer[offset..][0..8], self.to, .little);
        offset += 8;

        std.mem.writeInt(u16, buffer[offset..][0..2], self.label, .little);
        offset += 2;

        std.mem.writeInt(u16, buffer[offset..][0..2], self.properties_size, .little);
        offset += 2;

        return offset;
    }

    pub inline fn deserialize(buffer: []const u8) !EdgeMessage {
        assert(buffer.len >= SIZE);

        var offset: usize = 0;
        const message_type = @as(MessageType, @enumFromInt(buffer[offset]));
        offset += 1;

        const from = std.mem.readInt(u64, buffer[offset..][0..8], .little);
        offset += 8;

        const to = std.mem.readInt(u64, buffer[offset..][0..8], .little);
        offset += 8;

        const label = std.mem.readInt(u16, buffer[offset..][0..2], .little);
        offset += 2;

        const properties_size = std.mem.readInt(u16, buffer[offset..][0..2], .little);
        offset += 2;

        return EdgeMessage{
            .message_type = message_type,
            .from = from,
            .to = to,
            .label = label,
            .properties_size = properties_size,
        };
    }
};

// =============================================================================
// Batch Processor - TigerBeetle Style
// =============================================================================

pub const BatchProcessor = struct {
    // Static pre-allocated buffers
    node_buffer: [constants.batch.node_buffer_size]u8 align(constants.memory.simd_alignment),
    edge_buffer: [constants.batch.edge_buffer_size]u8 align(constants.memory.simd_alignment),
    vector_buffer: [constants.batch.vector_buffer_size]u8 align(constants.memory.simd_alignment),

    // Batch state
    node_count: u32 = 0,
    edge_count: u32 = 0,
    vector_count: u32 = 0,
    last_commit_time: i64 = 0,

    // Statistics
    stats: BatchStats = BatchStats{},

    // Configuration
    config: BatchConfig,

    pub fn init(config: BatchConfig) BatchProcessor {
        return BatchProcessor{
            .node_buffer = [_]u8{0} ** constants.batch.node_buffer_size,
            .edge_buffer = [_]u8{0} ** constants.batch.edge_buffer_size,
            .vector_buffer = [_]u8{0} ** constants.batch.vector_buffer_size,
            .config = config,
            .last_commit_time = std.time.timestamp(),
        };
    }

    // =============================================================================
    // Batch Operations (TigerBeetle Style)
    // =============================================================================

    /// Add node to batch (zero-copy)
    pub inline fn addNode(
        self: *BatchProcessor,
        id: u64,
        kind: u8,
        properties: ?[]const u8,
    ) !void {
        assert(id > 0);
        assert(self.node_count < self.config.max_batch_size);

        const properties_size = if (properties) |p| @as(u16, @intCast(p.len)) else 0;
        const total_size = NodeMessage.SIZE + properties_size;

        if (self.node_count * NodeMessage.SIZE + total_size > self.node_buffer.len) {
            return error.BatchFull;
        }

        const message = NodeMessage{
            .id = id,
            .kind = kind,
            .properties_size = properties_size,
        };

        const offset = self.node_count * NodeMessage.SIZE;
        _ = try message.serialize(self.node_buffer[offset..]);

        // Copy properties inline (zero-copy)
        if (properties) |p| {
            @memcpy(self.node_buffer[offset + NodeMessage.SIZE .. offset + total_size], p);
        }

        self.node_count += 1;
        self.stats.nodes_added += 1;
    }

    /// Add edge to batch (zero-copy)
    pub inline fn addEdge(
        self: *BatchProcessor,
        from: u64,
        to: u64,
        label: u16,
        properties: ?[]const u8,
    ) !void {
        assert(from > 0);
        assert(to > 0);
        assert(from != to);
        assert(self.edge_count < self.config.max_batch_size);

        const properties_size = if (properties) |p| @as(u16, @intCast(p.len)) else 0;
        const total_size = EdgeMessage.SIZE + properties_size;

        if (self.edge_count * EdgeMessage.SIZE + total_size > self.edge_buffer.len) {
            return error.BatchFull;
        }

        const message = EdgeMessage{
            .from = from,
            .to = to,
            .label = label,
            .properties_size = properties_size,
        };

        const offset = self.edge_count * EdgeMessage.SIZE;
        _ = try message.serialize(self.edge_buffer[offset..]);

        // Copy properties inline (zero-copy)
        if (properties) |p| {
            @memcpy(self.edge_buffer[offset + EdgeMessage.SIZE .. offset + total_size], p);
        }

        self.edge_count += 1;
        self.stats.edges_added += 1;
    }

    /// Check if batch should auto-commit
    pub inline fn shouldAutoCommit(self: *const BatchProcessor) bool {
        const total_messages = self.node_count + self.edge_count + self.vector_count;
        const time_since_last = std.time.timestamp() - self.last_commit_time;

        return total_messages >= self.config.auto_commit_threshold or
            time_since_last >= self.config.batch_timeout_ms;
    }

    /// Commit batch to graph data (SIMD-optimized)
    pub inline fn commit(self: *BatchProcessor, graph_data: *layout.GraphData) !void {
        if (self.node_count == 0 and self.edge_count == 0 and self.vector_count == 0) {
            return; // Nothing to commit
        }

        // Process nodes in SIMD batches
        if (self.node_count > 0) {
            try self.commitNodes(graph_data);
        }

        // Process edges in SIMD batches
        if (self.edge_count > 0) {
            try self.commitEdges(graph_data);
        }

        // Process vectors in SIMD batches
        if (self.vector_count > 0) {
            try self.commitVectors(graph_data);
        }

        // Reset batch state
        self.reset();

        self.stats.batches_committed += 1;
    }

    /// Commit nodes with SIMD optimization
    inline fn commitNodes(self: *BatchProcessor, graph_data: *layout.GraphData) !void {
        var i: u32 = 0;
        while (i < self.node_count) {
            const batch_size = @min(constants.data.simd_node_batch_size, self.node_count - i);

            // Process SIMD batch
            try self.processNodeBatch(graph_data, i, batch_size);

            i += batch_size;
        }
    }

    /// Commit edges with SIMD optimization
    inline fn commitEdges(self: *BatchProcessor, graph_data: *layout.GraphData) !void {
        var i: u32 = 0;
        while (i < self.edge_count) {
            const batch_size = @min(constants.data.simd_edge_batch_size, self.edge_count - i);

            // Process SIMD batch
            try self.processEdgeBatch(graph_data, i, batch_size);

            i += batch_size;
        }
    }

    /// Commit vectors with SIMD optimization
    inline fn commitVectors(self: *BatchProcessor, graph_data: *layout.GraphData) !void {
        var i: u32 = 0;
        while (i < self.vector_count) {
            const batch_size = @min(constants.data.simd_embedding_batch_size, self.vector_count - i);

            // Process SIMD batch
            try self.processVectorBatch(graph_data, i, batch_size);

            i += batch_size;
        }
    }

    /// Process node batch with SIMD
    inline fn processNodeBatch(
        self: *BatchProcessor,
        graph_data: *layout.GraphData,
        start_index: u32,
        batch_size: u32,
    ) !void {
        for (0..batch_size) |j| {
            const index = start_index + @as(u32, @intCast(j));
            const offset = index * NodeMessage.SIZE;

            const message = try NodeMessage.deserialize(self.node_buffer[offset..]);

            // Add to graph data
            _ = try graph_data.addNode(message.id, message.kind);
        }
    }

    /// Process edge batch with SIMD
    inline fn processEdgeBatch(
        self: *BatchProcessor,
        graph_data: *layout.GraphData,
        start_index: u32,
        batch_size: u32,
    ) !void {
        for (0..batch_size) |j| {
            const index = start_index + @as(u32, @intCast(j));
            const offset = index * EdgeMessage.SIZE;

            const message = try EdgeMessage.deserialize(self.edge_buffer[offset..]);

            // Add to graph data
            _ = try graph_data.addEdge(message.from, message.to, message.label);
        }
    }

    /// Process vector batch with SIMD
    inline fn processVectorBatch(
        self: *BatchProcessor,
        graph_data: *layout.GraphData,
        start_index: u32,
        batch_size: u32,
    ) !void {
        // TODO: Implement vector batch processing
        _ = self;
        _ = graph_data;
        _ = start_index;
        _ = batch_size;
    }

    /// Reset batch state
    pub inline fn reset(self: *BatchProcessor) void {
        self.node_count = 0;
        self.edge_count = 0;
        self.vector_count = 0;
        self.last_commit_time = std.time.timestamp();
    }

    /// Get batch statistics
    pub inline fn getStats(self: *const BatchProcessor) BatchStats {
        return self.stats;
    }

    /// Get current batch size
    pub inline fn getBatchSize(self: *const BatchProcessor) u32 {
        return self.node_count + self.edge_count + self.vector_count;
    }
};

// =============================================================================
// Batch Statistics
// =============================================================================

pub const BatchStats = struct {
    nodes_added: u64 = 0,
    edges_added: u64 = 0,
    vectors_added: u64 = 0,
    batches_committed: u64 = 0,
    auto_commits: u64 = 0,

    pub inline fn getTotalOperations(self: *const BatchStats) u64 {
        return self.nodes_added + self.edges_added + self.vectors_added;
    }

    pub inline fn getAverageBatchSize(self: *const BatchStats) f64 {
        if (self.batches_committed == 0) return 0.0;
        return @as(f64, @floatFromInt(self.getTotalOperations())) / @as(f64, @floatFromInt(self.batches_committed));
    }
};

// =============================================================================
// Tests
// =============================================================================

test "batch processor basic operations" {
    var processor = BatchProcessor.init(BatchConfig{});

    // Test node addition
    try processor.addNode(1, 100, null);
    try processor.addNode(2, 200, null);

    try std.testing.expectEqual(@as(u32, 2), processor.node_count);
    try std.testing.expectEqual(@as(u32, 0), processor.edge_count);

    // Test edge addition
    try processor.addEdge(1, 2, 50, null);

    try std.testing.expectEqual(@as(u32, 2), processor.node_count);
    try std.testing.expectEqual(@as(u32, 1), processor.edge_count);

    // Test auto-commit check
    const should_commit = processor.shouldAutoCommit();
    try std.testing.expect(!should_commit); // Should not auto-commit with small batch
}

test "batch processor serialization" {
    const message = NodeMessage{
        .id = 12345,
        .kind = 100,
        .properties_size = 0,
    };

    var buffer: [NodeMessage.SIZE]u8 = undefined;
    const written = try message.serialize(&buffer);

    try std.testing.expectEqual(NodeMessage.SIZE, written);

    const deserialized = try NodeMessage.deserialize(&buffer);
    try std.testing.expectEqual(message.id, deserialized.id);
    try std.testing.expectEqual(message.kind, deserialized.kind);
    try std.testing.expectEqual(message.properties_size, deserialized.properties_size);
}
