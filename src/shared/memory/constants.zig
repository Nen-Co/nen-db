//! Memory Constants for NenDB
//!
//! Defines constants used in memory management, allocation,
//! and data structure sizing.

const std = @import("std");

// Memory pool constants
pub const DEFAULT_NODE_POOL_SIZE = 10000;
pub const DEFAULT_EDGE_POOL_SIZE = 50000;
pub const DEFAULT_EMBEDDING_POOL_SIZE = 1000;
pub const DEFAULT_PROPERTY_POOL_SIZE = 10000;

// Maximum pool sizes
pub const MAX_NODE_POOL_SIZE = 100000000; // 100M nodes
pub const MAX_EDGE_POOL_SIZE = 1000000000; // 1B edges
pub const MAX_EMBEDDING_POOL_SIZE = 10000000; // 10M embeddings
pub const MAX_PROPERTY_POOL_SIZE = 100000000; // 100M properties

// Minimum pool sizes
pub const MIN_NODE_POOL_SIZE = 100;
pub const MIN_EDGE_POOL_SIZE = 1000;
pub const MIN_EMBEDDING_POOL_SIZE = 10;
pub const MIN_PROPERTY_POOL_SIZE = 100;

// Data structure sizes
pub const NODE_SIZE = 8 + 1 + 1 + 4 + 64; // id + kind + active + generation + properties
pub const EDGE_SIZE = 8 + 8 + 2 + 1 + 4 + 64; // from + to + label + active + generation + properties
pub const EMBEDDING_HEADER_SIZE = 8 + 1; // id + active
pub const PROPERTY_BLOCK_SIZE = 64;

// Memory alignment
pub const CACHE_LINE_SIZE = 64;
pub const SIMD_ALIGNMENT = 16;
pub const DEFAULT_ALIGNMENT = 8;

// Memory allocation strategies
pub const AllocationStrategy = enum {
    static,
    dynamic,
    hybrid,
};

// Memory profiles
pub const MemoryProfile = enum {
    minimal,
    balanced,
    performance,
    enterprise,
};

// Memory limits
pub const DEFAULT_MEMORY_LIMIT_MB = 1024; // 1GB
pub const MAX_MEMORY_LIMIT_MB = 1048576; // 1TB
pub const MIN_MEMORY_LIMIT_MB = 64; // 64MB

// Buffer sizes
pub const DEFAULT_BUFFER_SIZE = 4096;
pub const MAX_BUFFER_SIZE = 1048576; // 1MB
pub const MIN_BUFFER_SIZE = 1024;

// Cache constants
pub const DEFAULT_CACHE_SIZE = 1000;
pub const MAX_CACHE_SIZE = 1000000;
pub const MIN_CACHE_SIZE = 10;

// Memory statistics
pub const MemoryStats = struct {
    total_allocated: u64,
    total_used: u64,
    total_free: u64,
    allocation_count: u64,
    deallocation_count: u64,
    peak_usage: u64,

    pub fn getUtilization(self: *const @This()) f32 {
        if (self.total_allocated == 0) return 0.0;
        return @as(f32, @floatFromInt(self.total_used)) / @as(f32, @floatFromInt(self.total_allocated));
    }

    pub fn getPeakUtilization(self: *const @This()) f32 {
        if (self.total_allocated == 0) return 0.0;
        return @as(f32, @floatFromInt(self.peak_usage)) / @as(f32, @floatFromInt(self.total_allocated));
    }
};

// Utility functions
pub fn isValidPoolSize(size: u32, min_size: u32, max_size: u32) bool {
    return size >= min_size and size <= max_size;
}

pub fn isValidMemoryLimit(limit_mb: u32) bool {
    return limit_mb >= MIN_MEMORY_LIMIT_MB and limit_mb <= MAX_MEMORY_LIMIT_MB;
}

pub fn isValidBufferSize(size: u32) bool {
    return size >= MIN_BUFFER_SIZE and size <= MAX_BUFFER_SIZE;
}

pub fn isValidCacheSize(size: u32) bool {
    return size >= MIN_CACHE_SIZE and size <= MAX_CACHE_SIZE;
}

pub fn alignToCacheLine(size: u32) u32 {
    return ((size + CACHE_LINE_SIZE - 1) / CACHE_LINE_SIZE) * CACHE_LINE_SIZE;
}

pub fn alignToSimd(size: u32) u32 {
    return ((size + SIMD_ALIGNMENT - 1) / SIMD_ALIGNMENT) * SIMD_ALIGNMENT;
}

pub fn alignToDefault(size: u32) u32 {
    return ((size + DEFAULT_ALIGNMENT - 1) / DEFAULT_ALIGNMENT) * DEFAULT_ALIGNMENT;
}
