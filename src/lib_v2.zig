// NenDB Public Library API
// Production-ready interface following TigerBeetle patterns

const std = @import("std");
const constants = @import("constants.zig");
const nendb_core = @import("nendb_v2.zig");

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
    
    // WAL configuration
    wal_segment_size: u64 = constants.storage.wal_segment_size,
    sync_interval: u32 = constants.storage.sync_interval,
    
    // Features
    enable_wal: bool = constants.features.enable_wal,
    enable_compression: bool = constants.features.enable_compression,
    enable_metrics: bool = constants.features.enable_metrics,
};

// Convenience creation function
pub fn create(allocator: std.mem.Allocator, config: Config) !NenDB {
    return try NenDB.init(allocator, config.data_dir);
}

// Version information
pub const VERSION = "0.1.0-beta";
pub const FEATURES = struct {
    pub const STATIC_ALLOCATION = true;
    pub const ZERO_COPY = true;
    pub const AI_OPTIMIZED = true;
    pub const TIGERBEETLE_INSPIRED = true;
};

// Test helper for convenience
pub fn create_test_instance(allocator: std.mem.Allocator) !NenDB {
    return create(allocator, Config{ .data_dir = "./test_data" });
}
