// NenDB - Main Library Entry Point
// The world's first predictable, AI-native graph database

const std = @import("std");

// Core modules
pub const memory = @import("memory/pool.zig");
pub const query = @import("query/query.zig");
pub const nendb = @import("nendb.zig");

// Re-export main types for convenience
pub const NenDB = nendb.NenDB;
pub const NodeDef = nendb.NodeDef;
pub const EdgeDef = nendb.EdgeDef;
pub const BatchNodeInsert = nendb.BatchNodeInsert;
pub const BatchEdgeInsert = nendb.BatchEdgeInsert;
pub const BatchEmbeddingInsert = nendb.BatchEmbeddingInsert;
pub const MemoryStats = nendb.MemoryStats;

// Memory pool types
pub const NodePool = memory.NodePool;
pub const EdgePool = memory.EdgePool;
pub const EmbeddingPool = memory.EmbeddingPool;
pub const Node = memory.Node;
pub const Edge = memory.Edge;
pub const Embedding = memory.Embedding;

// Configuration
pub const Config = struct {
    node_pool_size: usize = memory.NODE_POOL_SIZE,
    edge_pool_size: usize = memory.EDGE_POOL_SIZE,
    embedding_pool_size: usize = memory.EMBEDDING_POOL_SIZE,
    embedding_dim: usize = memory.EMBEDDING_DIM,
    data_dir: []const u8 = ".",
};

// Convenience function to create a NenDB instance
pub fn create(allocator: std.mem.Allocator, config: Config) !NenDB {
    _ = config; // Future configuration options
    var node_pool = memory.NodePool{};
    var edge_pool = memory.EdgePool{};
    var embedding_pool = memory.EmbeddingPool{};
    
    return NenDB.init(allocator, &node_pool, &edge_pool, &embedding_pool);
}

// Version information
pub const VERSION = "0.1.0";
pub const VERSION_STRING = "NenDB v" ++ VERSION;

// Feature flags
pub const FEATURES = struct {
    pub const STATIC_ALLOCATION = true;
    pub const ZERO_GC = true;
    pub const BATCH_OPERATIONS = true;
    pub const AI_NATIVE = true;
    pub const PREDICTABLE_PERFORMANCE = true;
    pub const WAL_PERSISTENCE = true;
    pub const CYPHER_LIKE_QUERIES = true;
};

test "nendb basic functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var db = try create(allocator, Config{});
    defer db.deinit();
    
    // Test basic operations work
    const stats = db.get_memory_stats();
    try std.testing.expect(stats.nodes_used == 0);
    try std.testing.expect(stats.edges_used == 0);
    try std.testing.expect(stats.embeddings_used == 0);
}
