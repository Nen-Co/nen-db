//! Distributed NenDB (Framework Only)
//!
//! Framework for multi-user graph database optimized for enterprise workloads,
//! cloud services, and real-time analytics.
//!
//! Note: This is a framework structure only. Actual distributed features
//! (consensus, networking, replication) are not implemented yet.

// Import shared core functionality
const shared = @import("../shared/lib.zig");

// Distributed database implementation
pub const distributed = @import("distributed.zig");

// Re-export shared types for convenience
pub const Database = shared.Database;
pub const GraphDB = shared.GraphDB;
pub const Node = shared.Node;
pub const Edge = shared.Edge;
pub const GraphStats = shared.GraphStats;

// Distributed-specific types
pub const DistributedNode = distributed.DistributedNode;
pub const DistributedConfig = distributed.DistributedConfig;
