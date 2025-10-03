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

// Re-export embedded DB test/utility API for integration tests
pub const TCP_PORT = embedded.TCP_PORT;
pub const StaticDB = embedded.StaticDB;
pub const load_csv_into_db = embedded.load_csv_into_db;
pub const serialize_visualizer = embedded.serialize_visualizer;
pub const serve_single = embedded.serve_single;

// Re-export property graph model
pub const PropertyGraph = shared.PropertyGraph;
pub const PropertyType = shared.PropertyType;
pub const Property = shared.Property;
pub const NodeSchema = shared.NodeSchema;
pub const EdgeSchema = shared.EdgeSchema;

// Re-export columnar storage
pub const ColumnarStorage = shared.ColumnarStorage;
pub const ColumnType = shared.ColumnType;
pub const Column = shared.Column;
pub const CompressionType = shared.CompressionType;
pub const AggregationType = shared.AggregationType;

// Re-export vector storage
pub const VectorStorage = shared.VectorStorage;
pub const VectorIndex = shared.VectorIndex;
pub const VectorType = shared.VectorType;
pub const DistanceMetric = shared.DistanceMetric;
pub const SearchResult = shared.SearchResult;
