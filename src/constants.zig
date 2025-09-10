// NenDB Constants
// Production-ready configuration following TigerBeetle patterns

const std = @import("std");

// Version info - Update these values for each release
pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 2,
    .patch = 0,
    .pre = "beta",
};

// Formatted version strings for CLI and API
pub const VERSION_STRING = "v0.2.0-beta";
pub const VERSION_FULL = "NenDB v0.2.0-beta";
pub const VERSION_SHORT = "0.2.0";

// Memory Configuration - DOD-optimized static allocation
pub const memory = struct {
    // Pool sizes - can be configured at compile time
    pub const node_pool_size: u32 = if (@hasDecl(@import("root"), "NENDB_NODE_POOL_SIZE"))
        @import("root").NENDB_NODE_POOL_SIZE
    else
        4096;

    pub const edge_pool_size: u32 = if (@hasDecl(@import("root"), "NENDB_EDGE_POOL_SIZE"))
        @import("root").NENDB_EDGE_POOL_SIZE
    else
        4096;

    pub const embedding_pool_size: u32 = if (@hasDecl(@import("root"), "NENDB_EMBEDDING_POOL_SIZE"))
        @import("root").NENDB_EMBEDDING_POOL_SIZE
    else
        1024;

    // DOD-specific pool sizes
    pub const component_pool_size: u32 = 8192; // For component-based entities
    pub const property_pool_size: u32 = 16384; // For property storage
    pub const index_pool_size: u32 = 2048; // For index structures

    // Memory alignment (DOD-optimized)
    pub const cache_line_size = 64;
    pub const simd_alignment = 32; // For SIMD operations
    pub const sector_size = 512;
    pub const page_size = 4096;

    // Buffer sizes for batch operations (DOD-optimized)
    pub const batch_max = 8192;
    pub const message_size_max = 2048;
    pub const simd_batch_size = 8; // Process 8 elements at once with SIMD
};

// Batch Processing Configuration (TigerBeetle-style)
pub const batch = struct {
    pub const max_batch_size: u32 = 8192; // Maximum messages per batch
    pub const max_message_size: u32 = 64; // Fixed message size for predictability
    pub const batch_timeout_ms: u32 = 100; // Maximum time to wait for batch completion
    pub const auto_commit_threshold: u32 = 1000; // Auto-commit when batch reaches this size

    // Pre-allocated buffer sizes
    pub const node_buffer_size: u32 = max_batch_size * @sizeOf(@import("memory/pool.zig").Node);
    pub const edge_buffer_size: u32 = max_batch_size * @sizeOf(@import("memory/pool.zig").Edge);
    pub const vector_buffer_size: u32 = max_batch_size * 264; // 8 bytes node_id + 256 bytes vector

    // Performance tuning
    pub const enable_zero_copy: bool = true;
    pub const enable_atomic_commit: bool = true;
    pub const enable_batch_statistics: bool = true;
};

// Data Structure Constraints - DOD-optimized
pub const data = struct {
    pub const node_id_max = std.math.maxInt(u64);
    pub const node_kind_max = std.math.maxInt(u8);
    pub const node_props_size = 128;

    pub const edge_label_max = std.math.maxInt(u16);
    pub const edge_props_size = 64;

    pub const embedding_dimensions = 256; // TigerBeetle-style: start small, scale up after testing
    pub const embedding_id_max = std.math.maxInt(u64);

    // DOD-specific constraints
    pub const max_components_per_entity = 16; // Maximum components per entity
    pub const max_property_types = 32; // Maximum property types
    pub const max_relationship_types = 64; // Maximum relationship types

    // SIMD-optimized sizes (power of 2)
    pub const simd_node_batch_size = 8; // Process 8 nodes at once
    pub const simd_edge_batch_size = 8; // Process 8 edges at once
    pub const simd_embedding_batch_size = 8; // Process 8 embeddings at once
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

// Performance Tuning - DOD-optimized
pub const performance = struct {
    pub const prefetch_distance = 16;
    pub const hash_table_load_factor = 0.75;
    pub const bloom_filter_bits = 8;
    pub const compression_level = 1; // Fast compression

    // DOD-specific performance tuning
    pub const enable_simd = true; // Enable SIMD operations
    pub const enable_prefetch = true; // Enable data prefetching
    pub const enable_vectorization = true; // Enable vectorized operations
    pub const cache_line_prefetch = 2; // Prefetch 2 cache lines ahead
    pub const simd_prefetch_distance = 4; // Prefetch distance for SIMD operations
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

// DOD Configuration
pub const dod = struct {
    // Data layout configuration
    pub const use_soa_layout = true; // Use Struct of Arrays layout
    pub const separate_hot_cold = true; // Separate hot and cold data
    pub const enable_component_system = true; // Enable component-based architecture

    // Memory optimization
    pub const align_for_simd = true; // Align data for SIMD operations
    pub const use_memory_pools = true; // Use static memory pools
    pub const enable_memory_prefetch = true; // Enable memory prefetching

    // Performance optimization
    pub const enable_vectorization = true; // Enable vectorized operations
    pub const enable_batch_processing = true; // Enable batch processing
    pub const enable_parallel_components = true; // Enable parallel component processing

    // Cache optimization
    pub const optimize_cache_locality = true; // Optimize for cache locality
    pub const use_cache_friendly_layouts = true; // Use cache-friendly data layouts
    pub const enable_prefetch_hints = true; // Enable prefetch hints

    // SIMD configuration
    pub const simd_width = 8; // SIMD width (8 for AVX2, 16 for AVX-512)
    pub const enable_simd_operations = true; // Enable SIMD operations
    pub const simd_alignment = 32; // SIMD alignment requirement
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
