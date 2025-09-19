//! NenDB - AI-Native Graph Database
//!
//! Embedded graph database with distributed framework (in development)

// Import shared core functionality
pub const shared = @import("shared/lib.zig");

// Architecture-specific implementations
pub const embedded = @import("embedded/lib.zig");
pub const distributed = @import("distributed/lib.zig");

// Re-export shared types for convenience
pub const Database = shared.Database;
pub const GraphDB = shared.GraphDB;
pub const Node = shared.Node;
pub const Edge = shared.Edge;
pub const GraphStats = shared.GraphStats;

// Re-export architecture-specific types
pub const EmbeddedDB = embedded.EmbeddedDB;
pub const EmbeddedConfig = embedded.EmbeddedConfig;
pub const DistributedNode = distributed.DistributedNode;
pub const DistributedConfig = distributed.DistributedConfig;

// Re-export shared modules
pub const constants = shared.constants;
pub const memory = shared.memory;
pub const algorithms = shared.algorithms;
pub const concurrency = shared.concurrency;
pub const ai_ml = shared.ai_ml;
