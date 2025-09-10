// NenDB - Main Library Entry Point
// The world's first predictable, AI-native graph database

const std = @import("std");

// Core modules
pub const memory = @import("memory/pool_v2.zig");
// pub const query = @import("query/query.zig");
pub const constants = @import("constants.zig");

// Use nen-io and nen-json from the ecosystem instead of local implementations
pub const io = @import("nen-io");
pub const json = @import("nen-json");

// Legacy nendb.zig removed; GraphDB is primary engine now (graphdb.zig)
pub const graphdb = @import("graphdb.zig");

// Data-Oriented Design (DOD) modules
pub const dod = @import("memory/dod_layout.zig");
pub const simd = @import("memory/simd_operations.zig");
pub const prefetch = @import("memory/prefetch_system.zig");

// Batch processing system (TigerBeetle-style)
pub const batch = @import("batch/batch_processor.zig");
pub const client_batcher = @import("batch/client_batcher.zig");
pub const server_batcher = @import("batch/server_batcher.zig");

// Algorithms module
pub const algorithms = @import("algorithms/algorithms.zig");

// Networking APIs using nen-net
pub const api = struct {
    pub const server = @import("api/server.zig");
    pub const client = @import("api/client.zig");
};
// Re-export main types for convenience
pub const GraphDB = graphdb.GraphDB;
pub const MemoryStats = memory.MemoryStats; // per-pool stats, GraphDB aggregates separately

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
pub fn create_graph(allocator: std.mem.Allocator, config: Config) !GraphDB {
    _ = allocator; // GraphDB uses static pools internally
    // Use provided data_dir; ensure isolated path so multiple tests don't contend on WAL lock
    var db: GraphDB = undefined;
    try GraphDB.open_inplace(&db, config.data_dir);
    return db; // return by value (copy); caller should deinit()
}

// Simplified embedded API - no configuration needed
pub fn open(data_dir: []const u8) !GraphDB {
    var db: GraphDB = undefined;
    try GraphDB.open_inplace(&db, data_dir);
    return db;
}

// In-memory only database (no persistence)
pub fn open_memory() !GraphDB {
    return open(":memory:");
}

// Quick start with default configuration
pub fn init() !GraphDB {
    return open("./nendb_data");
}

// Version information
pub const VERSION = constants.VERSION_SHORT;
pub const VERSION_STRING = constants.VERSION_FULL;

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
    const tmp_dir = "./.nendb_lib_basic";
    _ = std.fs.cwd().deleteTree(tmp_dir) catch {};
    try std.fs.cwd().makePath(tmp_dir);
    var db = try create_graph(allocator, Config{ .data_dir = tmp_dir });
    defer {
        db.deinit();
        _ = std.fs.cwd().deleteTree(tmp_dir) catch {};
    }

    // Test basic operations work in fresh directory
    const stats = db.get_memory_stats();
    try std.testing.expectEqual(@as(u32, 0), stats.nodes.used);
    try std.testing.expectEqual(@as(u32, 0), stats.edges.used);
    try std.testing.expectEqual(@as(u32, 0), stats.embeddings.used);
}
