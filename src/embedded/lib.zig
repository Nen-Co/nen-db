//! Embedded NenDB
//!
//! Single-user graph database optimized for AI/ML workloads,
//! desktop applications, and edge computing.

// Import shared core functionality
const shared = @import("../shared/lib.zig");

// Embedded database implementation
const embedded_mod = @import("embedded.zig");

// Re-export core embedded DB types and functions for testing and CLI
pub const StaticDB = embedded_mod.StaticDB;
pub const load_csv_into_db = embedded_mod.load_csv_into_db;
pub const serialize_visualizer = embedded_mod.serialize_visualizer;
pub const serve_single = embedded_mod.serve_single;
pub const TCP_PORT = embedded_mod.TCP_PORT;

// Re-export shared types for convenience
pub const Database = shared.Database;
pub const GraphDB = shared.GraphDB;
pub const Node = shared.Node;
pub const Edge = shared.Edge;
pub const GraphStats = shared.GraphStats;

// Embedded-specific types
pub const EmbeddedDB = embedded_mod.EmbeddedDB;
pub const EmbeddedConfig = embedded_mod.EmbeddedConfig;
