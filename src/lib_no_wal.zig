// NenDB Public Library API (No WAL version for testing)
// Production-ready interface following TigerBeetle patterns

const std = @import("std");
const constants = @import("constants.zig");
const nendb_core = @import("nendb_no_wal.zig");

// Re-export core types
pub const NenDB = nendb_core.NenDB;
pub const NodeDef = nendb_core.NodeDef;
pub const EdgeDef = nendb_core.EdgeDef;
pub const EmbeddingDef = nendb_core.EmbeddingDef;
pub const BatchNodeInsert = nendb_core.BatchNodeInsert;
pub const BatchEdgeInsert = nendb_core.BatchEdgeInsert;
pub const BatchResult = nendb_core.BatchResult;
pub const DatabaseStats = nendb_core.DatabaseStats;

// Re-export constants
pub const NenDBError = constants.NenDBError;
pub const version = constants.version;

// Configuration structure
pub const Config = struct {
    data_dir: []const u8 = "./nendb_data",
    
    // Node pool configuration
    node_pool_size: u32 = constants.memory.node_pool_size,
    edge_pool_size: u32 = constants.memory.edge_pool_size,
    embedding_pool_size: u32 = constants.memory.embedding_pool_size,
    
    // Features
    enable_metrics: bool = constants.features.enable_metrics,
};

// Convenience creation function
pub fn create(allocator: std.mem.Allocator, config: Config) !NenDB {
    return try NenDB.init(allocator, config.data_dir);
}

// Version information
pub const VERSION = "0.1.0-beta-no-wal";
pub const FEATURES = struct {
    pub const STATIC_ALLOCATION = true;
    pub const ZERO_COPY = true;
    pub const AI_OPTIMIZED = true;
    pub const TIGERBEETLE_INSPIRED = true;
    pub const WAL_ENABLED = false; // Temporarily disabled
};

// Test helper for convenience
pub fn create_test_instance(allocator: std.mem.Allocator) !NenDB {
    return create(allocator, Config{ .data_dir = "./test_data" });
}
