pub const graph_types = @import("graph_types.zig");
pub const errors = @import("errors.zig");
pub const static_memory = @import("static_memory.zig");
pub const serialization = @import("serialization.zig");

// Core database engine
pub const core = @import("core/lib.zig");
pub const graphdb = @import("core/graphdb.zig");
pub const constants = @import("core/constants.zig");

// New TigerBeetle-style embedded database
pub const embedded_db = @import("core/embedded_db.zig");
pub const batch_processor = @import("core/batch_processor.zig");

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

// Re-export new embedded database types
pub const EmbeddedDB = embedded_db.EmbeddedDB;
pub const EmbeddedConfig = embedded_db.EmbeddedConfig;
pub const BatchProcessor = batch_processor.BatchProcessor;
pub const BatchConfig = batch_processor.BatchConfig;

// Re-export multi-process and production features
pub const file_locking = @import("core/file_locking.zig");
pub const production_wal = @import("core/production_wal.zig");
pub const shared_memory = @import("core/shared_memory.zig");
pub const memory_predictor = @import("core/memory_predictor.zig");

// Property Graph Model (KuzuDB feature replication)
pub const property_graph = @import("core/property_graph.zig");
pub const PropertyGraph = property_graph.PropertyGraph;
pub const PropertyType = property_graph.PropertyType;
pub const Property = property_graph.Property;
pub const NodeSchema = property_graph.NodeSchema;
pub const EdgeSchema = property_graph.EdgeSchema;

// Columnar Storage (KuzuDB feature replication)
pub const columnar_storage = @import("core/columnar_storage.zig");
pub const ColumnarStorage = columnar_storage.ColumnarStorage;
pub const ColumnType = columnar_storage.ColumnType;
pub const Column = columnar_storage.Column;
pub const CompressionType = columnar_storage.CompressionType;
pub const AggregationType = columnar_storage.AggregationType;

// Vector Storage (KuzuDB feature replication)
pub const vector_storage = @import("core/vector_storage.zig");
pub const VectorStorage = vector_storage.VectorStorage;
pub const VectorIndex = vector_storage.VectorIndex;
pub const VectorType = vector_storage.VectorType;
pub const DistanceMetric = vector_storage.DistanceMetric;
pub const SearchResult = vector_storage.SearchResult;
