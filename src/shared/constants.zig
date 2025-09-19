//! Shared Constants for NenDB
//! 
//! Defines constants used across the entire NenDB system.

const std = @import("std");

// Version information
pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 2,
    .patch = 2,
    .pre = "beta",
};

// Formatted version strings for CLI and API
pub const VERSION_STRING = "v0.2.2-beta";
pub const VERSION_FULL = "NenDB v0.2.2-beta";
pub const VERSION_SHORT = "0.2.2";

// Memory configuration constants
pub const DEFAULT_NODE_POOL_SIZE = 10000;
pub const DEFAULT_EDGE_POOL_SIZE = 50000;
pub const DEFAULT_EMBEDDING_POOL_SIZE = 1000;
pub const DEFAULT_PROPERTY_POOL_SIZE = 10000;
pub const DEFAULT_EMBEDDING_DIMENSIONS = 128;

// Maximum limits
pub const MAX_NODE_POOL_SIZE = 100000000; // 100M nodes
pub const MAX_EDGE_POOL_SIZE = 1000000000; // 1B edges
pub const MAX_EMBEDDING_POOL_SIZE = 10000000; // 10M embeddings
pub const MAX_PROPERTY_POOL_SIZE = 100000000; // 100M properties
pub const MAX_EMBEDDING_DIMENSIONS = 4096;

// Minimum limits
pub const MIN_NODE_POOL_SIZE = 100;
pub const MIN_EDGE_POOL_SIZE = 1000;
pub const MIN_EMBEDDING_POOL_SIZE = 10;
pub const MIN_PROPERTY_POOL_SIZE = 100;
pub const MIN_EMBEDDING_DIMENSIONS = 8;

// Data structure sizes
pub const NODE_SIZE = 8 + 1 + 1 + 4 + 64; // id + kind + active + generation + properties
pub const EDGE_SIZE = 8 + 8 + 2 + 1 + 4 + 64; // from + to + label + active + generation + properties
pub const EMBEDDING_HEADER_SIZE = 8 + 1; // id + active
pub const PROPERTY_BLOCK_SIZE = 64;

// Graph characteristics
pub const DEFAULT_AVERAGE_DEGREE = 5.0;
pub const MAX_AVERAGE_DEGREE = 1000.0;
pub const MIN_AVERAGE_DEGREE = 0.1;

// Performance constants
pub const DEFAULT_BATCH_SIZE = 1000;
pub const MAX_BATCH_SIZE = 100000;
pub const MIN_BATCH_SIZE = 1;

// Cache constants
pub const DEFAULT_CACHE_SIZE = 1000;
pub const MAX_CACHE_SIZE = 1000000;
pub const MIN_CACHE_SIZE = 10;

// Network constants
pub const DEFAULT_HTTP_PORT = 8080;
pub const DEFAULT_TCP_PORT = 9090;
pub const MAX_HTTP_PORT = 65535;
pub const MIN_HTTP_PORT = 1024;

// File I/O constants
pub const DEFAULT_BUFFER_SIZE = 4096;
pub const MAX_BUFFER_SIZE = 1048576; // 1MB
pub const MIN_BUFFER_SIZE = 1024;

// Error codes
pub const ErrorCode = enum(u32) {
    invalid_pool_size = 1,
    memory_allocation_failed = 2,
    invalid_dimensions = 3,
    file_not_found = 4,
    permission_denied = 5,
    invalid_format = 6,
    network_error = 7,
    timeout = 8,
    concurrency_error = 9,
    validation_failed = 10,
};

// Utility functions
pub fn isValidPoolSize(size: u32, min_size: u32, max_size: u32) bool {
    return size >= min_size and size <= max_size;
}

pub fn isValidEmbeddingDimensions(dims: u32) bool {
    return dims >= MIN_EMBEDDING_DIMENSIONS and dims <= MAX_EMBEDDING_DIMENSIONS;
}

pub fn isValidPort(port: u16) bool {
    return port >= MIN_HTTP_PORT and port <= MAX_HTTP_PORT;
}

pub fn isValidBatchSize(size: u32) bool {
    return size >= MIN_BATCH_SIZE and size <= MAX_BATCH_SIZE;
}

pub fn isValidCacheSize(size: u32) bool {
    return size >= MIN_CACHE_SIZE and size <= MAX_CACHE_SIZE;
}
