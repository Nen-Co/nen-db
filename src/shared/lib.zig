//! Shared NenDB Core Library
//!
//! This module provides the shared core functionality used by both
//! embedded and distributed NenDB implementations.

// Core database engine
pub const core = @import("core/lib.zig");
pub const graphdb = @import("core/graphdb.zig");
pub const constants = @import("core/constants.zig");

// Memory management
pub const memory = @import("memory/layout.zig");
pub const wal = @import("memory/wal.zig");
pub const simd = @import("memory/simd.zig");
pub const predictor = @import("memory/predictor.zig");

// Graph algorithms
pub const algorithms = @import("algorithms/algorithms.zig");

// Concurrency primitives
pub const concurrency = @import("concurrency/concurrency.zig");

// AI/ML features
pub const ai_ml = @import("ai_ml/ai_ml.zig");

// Re-export commonly used types
pub const Database = core.Database;
pub const GraphDB = graphdb.GraphDB;
pub const Node = core.Node;
pub const Edge = core.Edge;
pub const GraphStats = core.GraphStats;
