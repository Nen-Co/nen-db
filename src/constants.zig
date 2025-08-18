// NenDB Constants
// Production-ready configuration following TigerBeetle patterns

const std = @import("std");

// Version info
pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
    .pre = "beta",
};

// Memory Configuration - Static allocation for predictable performance
pub const memory = struct {
    // Pool sizes - can be configured at compile time
    pub const node_pool_size: u32 = if (@hasDecl(@import("root"), "NENDB_NODE_POOL_SIZE")) 
        @import("root").NENDB_NODE_POOL_SIZE else 4096;
        
    pub const edge_pool_size: u32 = if (@hasDecl(@import("root"), "NENDB_EDGE_POOL_SIZE")) 
        @import("root").NENDB_EDGE_POOL_SIZE else 4096;
        
    pub const embedding_pool_size: u32 = if (@hasDecl(@import("root"), "NENDB_EMBEDDING_POOL_SIZE")) 
        @import("root").NENDB_EMBEDDING_POOL_SIZE else 1024;
        
    // Memory alignment (following TigerBeetle's patterns)
    pub const cache_line_size = 64;
    pub const sector_size = 512;
    pub const page_size = 4096;
    
    // Buffer sizes for batch operations
    pub const batch_max = 8192;
    pub const message_size_max = 2048;
};

// Data Structure Constraints
pub const data = struct {
    pub const node_id_max = std.math.maxInt(u64);
    pub const node_kind_max = std.math.maxInt(u8);
    pub const node_props_size = 128;
    
    pub const edge_label_max = std.math.maxInt(u16);
    pub const edge_props_size = 64;
    
    pub const embedding_dimensions = 256; // TigerBeetle-style: start small, scale up after testing
    pub const embedding_id_max = std.math.maxInt(u64);
};

// Storage Configuration
pub const storage = struct {
    pub const wal_segment_size = 1024 * 1024; // 1MB segments
    pub const wal_max_segments = 1024;
    pub const snapshot_interval = 10000; // Operations between snapshots
    
    pub const file_size_max = 1024 * 1024 * 1024; // 1GB max file size
    pub const sync_interval = 100; // Sync every N operations
};

// Network Configuration (for future server mode)
pub const network = struct {
    pub const port_default = 3003;
    pub const connection_max = 1024;
    pub const request_timeout_ms = 30 * 1000; // 30 seconds
    pub const keepalive_ms = 30 * 1000;
};

// Query Engine Configuration
pub const query = struct {
    pub const max_recursion_depth = 100;
    pub const max_query_length = 8192;
    pub const max_results = 10000;
    pub const timeout_ms = 5000;
};

// Performance Tuning
pub const performance = struct {
    pub const prefetch_distance = 16;
    pub const hash_table_load_factor = 0.75;
    pub const bloom_filter_bits = 8;
    pub const compression_level = 1; // Fast compression
};

// Development & Testing
pub const development = struct {
    pub const log_level_default = if (std.builtin.mode == .Debug) .debug else .info;
    pub const assert_level = if (std.builtin.mode == .Debug) .all else .none;
    pub const test_iterations = 1000;
};

// Feature Flags
pub const features = struct {
    pub const enable_wal = true;
    pub const enable_compression = false; // TODO: Implement
    pub const enable_encryption = false; // TODO: Implement
    pub const enable_replication = false; // TODO: Implement
    pub const enable_metrics = true;
    pub const enable_query_cache = true;
};

// Error codes (following TigerBeetle's pattern)
pub const NenDBError = error{
    // Storage errors
    StorageFull,
    CorruptedData,
    IOError,
    FileNotFound,
    PermissionDenied,
    AlreadyLocked,
    
    // Memory errors
    OutOfMemory,
    PoolExhausted,
    InvalidAlignment,
    
    // Data errors
    InvalidNodeID,
    InvalidEdgeID,
    NodeNotFound,
    EdgeNotFound,
    DuplicateNode,
    DuplicateEdge,
    
    // Query errors
    InvalidQuery,
    QueryTimeout,
    RecursionLimit,
    
    // Network errors (future)
    ConnectionFailed,
    RequestTimeout,
    InvalidMessage,
    
    // Configuration errors
    InvalidConfiguration,
    FeatureNotEnabled,
};

// Compile-time assertions (TigerBeetle pattern)
comptime {
    // Ensure power-of-2 alignments
    std.debug.assert(memory.cache_line_size & (memory.cache_line_size - 1) == 0);
    std.debug.assert(memory.sector_size & (memory.sector_size - 1) == 0);
    std.debug.assert(memory.page_size & (memory.page_size - 1) == 0);
    
    // Ensure reasonable pool sizes
    std.debug.assert(memory.node_pool_size > 0);
    std.debug.assert(memory.edge_pool_size > 0);
    std.debug.assert(memory.embedding_pool_size > 0);
    const total_embedding_bytes = memory.embedding_pool_size * data.embedding_dimensions * @sizeOf(f32);
    std.debug.assert(total_embedding_bytes < 10 * 1024 * 1024); // <10MB for safety
    
    // Ensure data structure sizes are aligned
    std.debug.assert(data.node_props_size % 8 == 0);
    std.debug.assert(data.edge_props_size % 8 == 0);
}
