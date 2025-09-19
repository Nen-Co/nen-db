//! Embedded NenDB
//!
//! Single-user graph database optimized for AI/ML workloads,
//! desktop applications, and edge computing.

// Import shared core functionality
const shared = @import("../shared/lib.zig");

// Embedded database implementation
pub const embedded = @import("embedded.zig");

// Re-export shared types for convenience
pub const Database = shared.Database;
pub const GraphDB = shared.GraphDB;
pub const Node = shared.Node;
pub const Edge = shared.Edge;
pub const GraphStats = shared.GraphStats;

// Embedded-specific types
pub const EmbeddedDB = embedded.EmbeddedDB;
pub const EmbeddedConfig = embedded.EmbeddedConfig;
