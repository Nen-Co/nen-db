// NenDB Embedded Database - KuzuDB Compatible with TigerBeetle Patterns
// Implements high-performance embedded graph database with static memory allocation

const std = @import("std");
const assert = std.debug.assert;
const constants = @import("../constants.zig");
const layout = @import("../memory/layout.zig");
const batch_processor = @import("batch_processor.zig");
const wal = @import("../memory/wal.zig");

// New multi-process and production features
const file_locking = @import("file_locking.zig");
const production_wal = @import("production_wal.zig");
const shared_memory = @import("shared_memory.zig");
const memory_predictor = @import("memory_predictor.zig");

// =============================================================================
// Embedded Database Configuration
// =============================================================================

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};

pub const EmbeddedConfig = struct {
    // Memory configuration
    max_nodes: u32 = constants.DEFAULT_NODE_POOL_SIZE,
    max_edges: u32 = constants.DEFAULT_EDGE_POOL_SIZE,
    max_properties: u32 = constants.DEFAULT_PROPERTY_POOL_SIZE,
    max_vectors: u32 = constants.DEFAULT_EMBEDDING_POOL_SIZE,
    vector_dimensions: u32 = constants.DEFAULT_EMBEDDING_DIMENSIONS,

    // Performance settings
    enable_simd: bool = true,
    enable_wal: bool = true,
    enable_batching: bool = true,
    enable_vector_search: bool = true,

    // Multi-process support
    enable_multi_process: bool = false,
    enable_file_locking: bool = true,
    enable_shared_memory: bool = false,

    // Production features
    enable_production_wal: bool = false,
    enable_memory_prediction: bool = false,

    // Batch configuration
    batch_config: batch_processor.BatchConfig = batch_processor.BatchConfig{},

    // Data directory
    data_dir: []const u8 = "embedded_data",

    // Logging
    log_level: LogLevel = .info,
};

// =============================================================================
// Embedded Database Implementation
// =============================================================================

const SimilarityResult = struct { node_id: u64, similarity: f32 };

pub const EmbeddedDB = struct {
    // Core graph data (static allocation)
    graph_data: layout.GraphData,

    // Batch processor (TigerBeetle style)
    batch_processor: batch_processor.BatchProcessor,

    // WAL for persistence
    wal: ?wal.Wal = null,
    production_wal: ?production_wal.ProductionWal = null,

    // Multi-process support
    file_lock_manager: ?file_locking.FileLockManager = null,
    process_coordinator: ?file_locking.ProcessCoordinator = null,
    shared_memory_coordinator: ?shared_memory.SharedMemoryCoordinator = null,

    // Memory prediction
    memory_predictor: ?memory_predictor.AdvancedMemoryPredictor = null,

    // Configuration
    config: EmbeddedConfig,

    // Statistics
    stats: DatabaseStats = DatabaseStats{},

    // Performance monitoring
    performance: PerformanceMetrics = PerformanceMetrics{},

    pub fn init(allocator: std.mem.Allocator, config: EmbeddedConfig) !EmbeddedDB {
        assert(config.max_nodes > 0);
        assert(config.max_edges > 0);
        assert(config.max_properties > 0);

        // Initialize graph data with static memory
        const graph_data = layout.GraphData.init(allocator);

        // Initialize batch processor
        const batch_proc = batch_processor.BatchProcessor.init(config.batch_config);

        // Initialize WAL if enabled
        var wal_instance: ?wal.Wal = null;
        if (config.enable_wal and !config.enable_production_wal) {
            wal_instance = try wal.Wal.open(config.data_dir);
        }

        // Initialize production WAL if enabled
        var prod_wal_instance: ?production_wal.ProductionWal = null;
        if (config.enable_production_wal) {
            prod_wal_instance = try production_wal.ProductionWal.init(config.data_dir);
            try prod_wal_instance.?.open();
        }

        // Initialize file locking if enabled
        var file_lock: ?file_locking.FileLockManager = null;
        var process_coord: ?file_locking.ProcessCoordinator = null;
        if (config.enable_file_locking) {
            file_lock = try file_locking.FileLockManager.init(allocator, config.data_dir);
            process_coord = try file_locking.ProcessCoordinator.init(allocator, config.data_dir);
        }

        // Initialize shared memory coordination if enabled
        var shared_mem: ?shared_memory.SharedMemoryCoordinator = null;
        if (config.enable_shared_memory) {
            shared_mem = try shared_memory.SharedMemoryCoordinator.init(allocator);
            try shared_mem.?.attach();
        }

        // Initialize memory predictor if enabled
        var mem_predictor: ?memory_predictor.AdvancedMemoryPredictor = null;
        if (config.enable_memory_prediction) {
            mem_predictor = memory_predictor.AdvancedMemoryPredictor.init(allocator);
        }

        return EmbeddedDB{
            .graph_data = graph_data,
            .batch_processor = batch_proc,
            .wal = wal_instance,
            .production_wal = prod_wal_instance,
            .file_lock_manager = file_lock,
            .process_coordinator = process_coord,
            .shared_memory_coordinator = shared_mem,
            .memory_predictor = mem_predictor,
            .config = config,
        };
    }

    pub fn deinit(self: *EmbeddedDB) void {
        // Close production WAL if it exists
        if (self.production_wal) |*w| {
            w.close() catch {};
        }

        // Close WAL if it exists
        if (self.wal) |*w| {
            w.close();
        }

        // Clean up multi-process resources
        if (self.process_coordinator) |*coord| {
            coord.deinit();
        }

        if (self.file_lock_manager) |*lock| {
            lock.deinit();
        }

        if (self.shared_memory_coordinator) |*shared| {
            shared.deinit();
        }

        if (self.memory_predictor) |*predictor| {
            predictor.deinit();
        }

        // Graph data cleanup (no dynamic allocations)
        self.graph_data.deinit();
    }

    // =============================================================================
    // Multi-Process Support Methods
    // =============================================================================

    /// Acquire exclusive access to the database
    pub fn acquireExclusiveAccess(self: *EmbeddedDB) !file_locking.LockResult {
        if (self.process_coordinator) |*coord| {
            return coord.acquireExclusiveAccess();
        }
        return .acquired; // No locking if disabled
    }

    /// Acquire shared access to the database
    pub fn acquireSharedAccess(self: *EmbeddedDB) !file_locking.LockResult {
        if (self.process_coordinator) |*coord| {
            return coord.acquireSharedAccess();
        }
        return .acquired; // No locking if disabled
    }

    /// Release database access
    pub fn releaseAccess(self: *EmbeddedDB) !void {
        if (self.process_coordinator) |*coord| {
            try coord.releaseAccess();
        }
    }

    /// Check if we have exclusive access
    pub fn hasExclusiveAccess(self: *const EmbeddedDB) bool {
        if (self.process_coordinator) |*coord| {
            return coord.hasExclusiveAccess();
        }
        return true; // Assume exclusive if no locking
    }

    /// Check if we have shared access
    pub fn hasSharedAccess(self: *const EmbeddedDB) bool {
        if (self.process_coordinator) |*coord| {
            return coord.hasSharedAccess();
        }
        return true; // Assume shared if no locking
    }

    /// Send heartbeat for multi-process coordination
    pub fn sendHeartbeat(self: *EmbeddedDB) !void {
        if (self.shared_memory_coordinator) |*coord| {
            try coord.sendHeartbeat();
        }
    }

    /// Get list of active processes
    pub fn getActiveProcesses(self: *EmbeddedDB) ![]shared_memory.ProcessInfo {
        if (self.shared_memory_coordinator) |*coord| {
            return coord.getActiveProcesses();
        }
        return &[_]shared_memory.ProcessInfo{};
    }

    /// Clean up dead processes
    pub fn cleanupDeadProcesses(self: *EmbeddedDB) !u32 {
        if (self.shared_memory_coordinator) |*coord| {
            return coord.cleanupDeadProcesses();
        }
        return 0;
    }

    // =============================================================================
    // Node Operations (KuzuDB Compatible)
    // =============================================================================

    /// Add a node to the database
    pub inline fn addNode(
        self: *EmbeddedDB,
        id: u64,
        label: []const u8,
        properties: ?[]const u8,
    ) !void {
        assert(id > 0);
        assert(label.len > 0);

        // Acquire appropriate lock
        if (self.config.enable_file_locking) {
            const lock_result = try self.acquireExclusiveAccess();
            if (lock_result != .acquired) {
                return error.LockTimeout;
            }
            defer self.releaseAccess() catch {};
        }

        // Use memory prediction if enabled
        if (self.memory_predictor) |*predictor| {
            const prediction = try predictor.predictAllocation(.node_insert);
            // Use prediction for optimization (could pre-allocate memory)
            _ = prediction; // TODO: Implement pre-allocation based on prediction
        }

        // Use batch processing if enabled
        if (self.config.enable_batching) {
            try self.batch_processor.addNode(id, self.getLabelId(label), properties);

            // Auto-commit if needed
            if (self.batch_processor.shouldAutoCommit()) {
                try self.commitBatch();
            }
        } else {
            // Direct insertion
            try self.insertNodeDirect(id, self.getLabelId(label), properties);
        }

        // Log to production WAL if enabled
        if (self.production_wal) |*w| {
            try w.writeNodeInsert(id, self.getLabelId(label), properties);
        }

        // Record allocation for memory prediction
        if (self.memory_predictor) |*predictor| {
            try predictor.recordAllocation(.node_insert, label.len + (properties.?.len orelse 0), label.len + (properties.?.len orelse 0), true);
        }

        self.stats.nodes_inserted += 1;
    }

    /// Add multiple nodes in batch (KuzuDB bulk loading)
    pub inline fn addNodesBatch(
        self: *EmbeddedDB,
        nodes: []const NodeData,
    ) !void {
        assert(nodes.len > 0);
        assert(nodes.len <= self.config.batch_config.max_batch_size);

        // Add all nodes to batch
        for (nodes) |node| {
            try self.batch_processor.addNode(node.id, node.kind, node.properties);
        }

        // Commit the entire batch
        try self.commitBatch();

        self.stats.bulk_operations += 1;
    }

    /// Insert node directly (bypass batching)
    inline fn insertNodeDirect(
        self: *EmbeddedDB,
        id: u64,
        kind: u8,
        properties: ?[]const u8,
    ) !void {
        // Add to graph data
        _ = try self.graph_data.addNodeWithWal(id, kind, if (self.wal) |*w| w else null);

        // Store properties if provided
        if (properties) |props| {
            try self.storeNodeProperties(id, props);
        }
    }

    // =============================================================================
    // Edge Operations (KuzuDB Compatible)
    // =============================================================================

    /// Add an edge to the database
    pub inline fn addEdge(
        self: *EmbeddedDB,
        from: u64,
        to: u64,
        label: []const u8,
        properties: ?[]const u8,
    ) !void {
        assert(from > 0);
        assert(to > 0);
        assert(from != to);
        assert(label.len > 0);

        // Use batch processing if enabled
        if (self.config.enable_batching) {
            try self.batch_processor.addEdge(from, to, self.getLabelId(label), properties);

            // Auto-commit if needed
            if (self.batch_processor.shouldAutoCommit()) {
                try self.commitBatch();
            }
        } else {
            // Direct insertion
            try self.insertEdgeDirect(from, to, self.getLabelId(label), properties);
        }

        self.stats.edges_inserted += 1;
    }

    /// Add multiple edges in batch (KuzuDB bulk loading)
    pub inline fn addEdgesBatch(
        self: *EmbeddedDB,
        edges: []const EdgeData,
    ) !void {
        assert(edges.len > 0);
        assert(edges.len <= self.config.batch_config.max_batch_size);

        // Add all edges to batch
        for (edges) |edge| {
            try self.batch_processor.addEdge(edge.from, edge.to, edge.label, edge.properties);
        }

        // Commit the entire batch
        try self.commitBatch();

        self.stats.bulk_operations += 1;
    }

    /// Insert edge directly (bypass batching)
    inline fn insertEdgeDirect(
        self: *EmbeddedDB,
        from: u64,
        to: u64,
        label: u16,
        properties: ?[]const u8,
    ) !void {
        // Add to graph data
        _ = try self.graph_data.addEdgeWithWal(from, to, label, if (self.wal) |*w| w else null);

        // Store properties if provided
        if (properties) |props| {
            try self.storeEdgeProperties(from, to, props);
        }
    }

    // =============================================================================
    // Query Operations (KuzuDB Compatible)
    // =============================================================================

    /// Find node by ID
    pub inline fn findNode(self: *const EmbeddedDB, id: u64) ?NodeInfo {
        const index = self.graph_data.findNodeById(id);
        return if (index) |idx| NodeInfo{
            .id = id,
            .kind = self.graph_data.node_kinds[idx],
            .index = idx,
        } else null;
    }

    /// Find edges by node (outgoing)
    pub inline fn findOutgoingEdges(
        self: *const EmbeddedDB,
        node_id: u64,
        result_indices: []u32,
    ) u32 {
        return self.graph_data.findEdgesByNode(node_id, true, result_indices);
    }

    /// Find edges by node (incoming)
    pub inline fn findIncomingEdges(
        self: *const EmbeddedDB,
        node_id: u64,
        result_indices: []u32,
    ) u32 {
        return self.graph_data.findEdgesByNode(node_id, false, result_indices);
    }

    /// Filter nodes by kind
    pub inline fn filterNodesByKind(
        self: *const EmbeddedDB,
        kind: u8,
        result_indices: []u32,
    ) u32 {
        return self.graph_data.filterNodesByKind(kind, result_indices);
    }

    /// Filter edges by label
    pub inline fn filterEdgesByLabel(
        self: *const EmbeddedDB,
        label: u16,
        result_indices: []u32,
    ) u32 {
        return self.graph_data.filterEdgesByLabel(label, result_indices);
    }

    // =============================================================================
    // Vector Search (KuzuDB Compatible)
    // =============================================================================

    /// Add vector embedding to node
    pub inline fn addVector(
        self: *EmbeddedDB,
        node_id: u64,
        vector: []const f32,
    ) !void {
        assert(vector.len == self.config.vector_dimensions);
        assert(node_id > 0);

        // Convert to fixed-size array
        var embedding: [constants.DEFAULT_EMBEDDING_DIMENSIONS]f32 = undefined;
        @memcpy(embedding[0..vector.len], vector);

        // Add to graph data
        _ = try self.graph_data.addEmbedding(node_id, embedding);

        self.stats.vectors_inserted += 1;
    }

    /// Find similar vectors (cosine similarity)
    pub inline fn findSimilarVectors(
        self: *const EmbeddedDB,
        query_vector: []const f32,
        top_k: u32,
        result_nodes: []u64,
    ) u32 {
        assert(query_vector.len == self.config.vector_dimensions);
        assert(top_k > 0);
        assert(result_nodes.len >= top_k);

        var similarities: [1000]SimilarityResult = undefined;
        var count: u32 = 0;

        // Compute similarities for all embeddings
        for (0..self.graph_data.embedding_count) |i| {
            if (!self.graph_data.embedding_active[i]) continue;

            const similarity = self.computeCosineSimilarity(
                query_vector,
                self.graph_data.embedding_vectors[i][0..self.config.vector_dimensions],
            );

            if (count < similarities.len) {
                similarities[count] = .{
                    .node_id = self.graph_data.embedding_node_ids[i],
                    .similarity = similarity,
                };
                count += 1;
            }
        }

        // Sort by similarity (simple bubble sort for small datasets)
        self.sortSimilarities(similarities[0..count]);

        // Return top-k results
        const result_count = @min(top_k, count);
        for (0..result_count) |i| {
            result_nodes[i] = similarities[i].node_id;
        }

        return result_count;
    }

    // =============================================================================
    // Batch Management
    // =============================================================================

    /// Commit pending batch operations
    pub inline fn commitBatch(self: *EmbeddedDB) !void {
        try self.batch_processor.commit(&self.graph_data);
        self.stats.batches_committed += 1;
    }

    /// Force commit all pending operations
    pub inline fn flush(self: *EmbeddedDB) !void {
        try self.commitBatch();

        // Flush WAL if it exists
        if (self.wal) |*w| {
            try w.flush();
        }
    }

    // =============================================================================
    // Statistics and Monitoring
    // =============================================================================

    /// Get database statistics
    pub inline fn getStats(self: *const EmbeddedDB) DatabaseStats {
        var stats = self.stats;
        const graph_stats = self.graph_data.getStats();

        stats.nodes_count = graph_stats.node_count;
        stats.edges_count = graph_stats.edge_count;
        stats.vectors_count = graph_stats.embedding_count;
        stats.memory_utilization = graph_stats.getUtilization();

        return stats;
    }

    /// Get performance metrics
    pub inline fn getPerformanceMetrics(self: *const EmbeddedDB) PerformanceMetrics {
        return self.performance;
    }

    /// Get batch processor statistics
    pub inline fn getBatchStats(self: *const EmbeddedDB) batch_processor.BatchStats {
        return self.batch_processor.getStats();
    }

    // =============================================================================
    // Helper Functions
    // =============================================================================

    /// Get label ID from string (simple hash)
    inline fn getLabelId(self: *const EmbeddedDB, label: []const u8) u8 {
        _ = self;
        // Simple hash function for label to ID mapping
        var hash: u8 = 0;
        for (label) |byte| {
            hash ^= byte;
            hash = hash *% 31;
        }
        return hash;
    }

    /// Store node properties
    inline fn storeNodeProperties(self: *EmbeddedDB, node_id: u64, properties: []const u8) !void {
        // TODO: Implement property storage
        _ = self;
        _ = node_id;
        _ = properties;
    }

    /// Store edge properties
    inline fn storeEdgeProperties(self: *EmbeddedDB, from: u64, to: u64, properties: []const u8) !void {
        // TODO: Implement property storage
        _ = self;
        _ = from;
        _ = to;
        _ = properties;
    }

    /// Compute cosine similarity between two vectors
    inline fn computeCosineSimilarity(
        self: *const EmbeddedDB,
        a: []const f32,
        b: []const f32,
    ) f32 {
        _ = self;
        assert(a.len == b.len);

        var dot_product: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;

        for (a, b) |val_a, val_b| {
            dot_product += val_a * val_b;
            norm_a += val_a * val_a;
            norm_b += val_b * val_b;
        }

        if (norm_a == 0.0 or norm_b == 0.0) return 0.0;

        return dot_product / (@sqrt(norm_a) * @sqrt(norm_b));
    }

    /// Sort similarities by score (bubble sort for small datasets)
    inline fn sortSimilarities(
        self: *const EmbeddedDB,
        similarities: []SimilarityResult,
    ) void {
        _ = self;

        // Simple bubble sort
        var i: usize = 0;
        while (i < similarities.len) {
            var j: usize = 0;
            while (j < similarities.len - 1 - i) {
                if (similarities[j].similarity < similarities[j + 1].similarity) {
                    const temp = similarities[j];
                    similarities[j] = similarities[j + 1];
                    similarities[j + 1] = temp;
                }
                j += 1;
            }
            i += 1;
        }
    }
};

// =============================================================================
// Data Structures
// =============================================================================

pub const NodeData = struct {
    id: u64,
    kind: u8,
    properties: ?[]const u8 = null,
};

pub const EdgeData = struct {
    from: u64,
    to: u64,
    label: u16,
    properties: ?[]const u8 = null,
};

pub const NodeInfo = struct {
    id: u64,
    kind: u8,
    index: u32,
};

pub const DatabaseStats = struct {
    nodes_count: u32 = 0,
    edges_count: u32 = 0,
    vectors_count: u32 = 0,
    nodes_inserted: u64 = 0,
    edges_inserted: u64 = 0,
    vectors_inserted: u64 = 0,
    batches_committed: u64 = 0,
    bulk_operations: u64 = 0,
    memory_utilization: f32 = 0.0,
};

pub const PerformanceMetrics = struct {
    avg_insert_time_ns: u64 = 0,
    avg_query_time_ns: u64 = 0,
    avg_batch_time_ns: u64 = 0,
    total_operations: u64 = 0,
};

// =============================================================================
// Tests
// =============================================================================

test "embedded database basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = EmbeddedConfig{
        .enable_batching = false, // Test direct operations
        .enable_wal = false,
    };

    var db = try EmbeddedDB.init(allocator, config);
    defer db.deinit();

    // Test node insertion
    try db.addNode(1, "Person", null);
    try db.addNode(2, "Company", null);

    // Test edge insertion
    try db.addEdge(1, 2, "WORKS_AT", null);

    // Test queries
    const node = db.findNode(1);
    try std.testing.expect(node != null);
    try std.testing.expectEqual(@as(u64, 1), node.?.id);

    // Test statistics
    const stats = db.getStats();
    try std.testing.expectEqual(@as(u32, 2), stats.nodes_count);
    try std.testing.expectEqual(@as(u32, 1), stats.edges_count);
}

test "embedded database batch operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = EmbeddedConfig{
        .enable_batching = true,
        .enable_wal = false,
    };

    var db = try EmbeddedDB.init(allocator, config);
    defer db.deinit();

    // Test batch node insertion
    const nodes = [_]NodeData{
        .{ .id = 1, .kind = 100 },
        .{ .id = 2, .kind = 200 },
        .{ .id = 3, .kind = 100 },
    };

    try db.addNodesBatch(&nodes);

    // Test batch edge insertion
    const edges = [_]EdgeData{
        .{ .from = 1, .to = 2, .label = 50 },
        .{ .from = 2, .to = 3, .label = 51 },
    };

    try db.addEdgesBatch(&edges);

    // Verify results
    const stats = db.getStats();
    try std.testing.expectEqual(@as(u32, 3), stats.nodes_count);
    try std.testing.expectEqual(@as(u32, 2), stats.edges_count);
}
