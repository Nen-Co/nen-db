// NenDB Memory Predictor - Static Allocation with Prediction
// Determines optimal memory allocation based on graph characteristics

const std = @import("std");
const constants = @import("constants.zig");

// =============================================================================
// Graph Characteristics for Memory Prediction
// =============================================================================

pub const GraphProfile = enum {
    sparse, // Social network: 2-10 edges per node
    medium, // Knowledge graph: 10-50 edges per node
    dense, // Dense graph: 50-200 edges per node
    hyper_dense, // Mesh network: 200+ edges per node
    ai_workload, // AI/ML: High embedding usage
    mixed, // Combination of above
};

pub const WorkloadType = enum {
    social_network, // Facebook, Twitter-like
    knowledge_graph, // Wikipedia, Wikidata-like
    recommendation, // E-commerce, content recommendation
    ai_training, // ML model training
    real_time_analytics, // Live data processing
    batch_processing, // ETL, data warehousing
};

// =============================================================================
// Memory Prediction Engine
// =============================================================================

pub const MemoryPredictor = struct {
    // Graph characteristics
    expected_nodes: u32,
    expected_edges: u32,
    avg_degree: f32,
    property_density: f32, // 0.0 to 1.0
    embedding_ratio: f32, // 0.0 to 1.0
    embedding_dims: u32,

    // Workload characteristics
    profile: GraphProfile,
    workload: WorkloadType,

    // Memory safety margins
    safety_margin: f32 = 1.5, // 50% safety margin
    growth_factor: f32 = 2.0, // 2x growth capacity

    pub fn init(
        expected_nodes: u32,
        expected_edges: u32,
        profile: GraphProfile,
        workload: WorkloadType,
        embedding_dims: u32,
    ) MemoryPredictor {
        const avg_degree = if (expected_nodes > 0)
            @as(f32, @floatFromInt(expected_edges)) / @as(f32, @floatFromInt(expected_nodes))
        else
            0.0;

        return MemoryPredictor{
            .expected_nodes = expected_nodes,
            .expected_edges = expected_edges,
            .avg_degree = avg_degree,
            .property_density = switch (workload) {
                .social_network => 0.1, // Minimal properties
                .knowledge_graph => 0.8, // Rich properties
                .recommendation => 0.3, // Moderate properties
                .ai_training => 0.2, // Focus on embeddings
                .real_time_analytics => 0.1,
                .batch_processing => 0.5,
            },
            .embedding_ratio = switch (workload) {
                .ai_training => 1.0, // All nodes have embeddings
                .recommendation => 0.8, // Most nodes have embeddings
                .social_network => 0.1, // Few embeddings
                .knowledge_graph => 0.3, // Some embeddings
                .real_time_analytics => 0.2,
                .batch_processing => 0.1,
            },
            .embedding_dims = embedding_dims,
            .profile = profile,
            .workload = workload,
        };
    }

    // =============================================================================
    // Memory Size Calculations
    // =============================================================================

    pub fn predictNodePoolSize(self: *const MemoryPredictor) u32 {
        const base_size = self.expected_nodes;
        const with_growth = @as(u32, @intFromFloat(@as(f32, @floatFromInt(base_size)) * self.growth_factor));
        const with_safety = @as(u32, @intFromFloat(@as(f32, @floatFromInt(with_growth)) * self.safety_margin));

        // Round up to nearest power of 2 for better cache performance
        return std.math.ceilPowerOfTwo(u32, with_safety) catch with_safety;
    }

    pub fn predictEdgePoolSize(self: *const MemoryPredictor) u32 {
        const base_size = self.expected_edges;
        const with_growth = @as(u32, @intFromFloat(@as(f32, @floatFromInt(base_size)) * self.growth_factor));
        const with_safety = @as(u32, @intFromFloat(@as(f32, @floatFromInt(with_growth)) * self.safety_margin));

        return std.math.ceilPowerOfTwo(u32, with_safety) catch with_safety;
    }

    pub fn predictEmbeddingPoolSize(self: *const MemoryPredictor) u32 {
        const nodes_with_embeddings = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.expected_nodes)) * self.embedding_ratio));
        const with_growth = @as(u32, @intFromFloat(@as(f32, @floatFromInt(nodes_with_embeddings)) * self.growth_factor));
        const with_safety = @as(u32, @intFromFloat(@as(f32, @floatFromInt(with_growth)) * self.safety_margin));

        return std.math.ceilPowerOfTwo(u32, with_safety) catch with_safety;
    }

    pub fn predictPropertyPoolSize(self: *const MemoryPredictor) u32 {
        const avg_properties_per_node = 1.0 + (self.property_density * 10.0); // 1-11 properties
        const total_properties = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.expected_nodes)) * avg_properties_per_node));
        const with_growth = @as(u32, @intFromFloat(@as(f32, @floatFromInt(total_properties)) * self.growth_factor));
        const with_safety = @as(u32, @intFromFloat(@as(f32, @floatFromInt(with_growth)) * self.safety_margin));

        return std.math.ceilPowerOfTwo(u32, with_safety) catch with_safety;
    }

    // =============================================================================
    // Memory Usage Estimation
    // =============================================================================

    pub fn estimateTotalMemory(self: *const MemoryPredictor) u64 {
        const node_pool = self.predictNodePoolSize();
        const edge_pool = self.predictEdgePoolSize();
        const embedding_pool = self.predictEmbeddingPoolSize();
        const property_pool = self.predictPropertyPoolSize();

        // Node memory (SoA layout)
        const node_memory = node_pool * (8 + 1 + 1 + 4 + 64); // id + kind + active + generation + properties

        // Edge memory (SoA layout)
        const edge_memory = edge_pool * (8 + 8 + 2 + 1 + 4 + 64); // from + to + label + active + generation + properties

        // Embedding memory
        const embedding_memory = embedding_pool * (8 + self.embedding_dims * 4 + 1); // id + vector + active

        // Property memory
        const property_memory = property_pool * 64; // PropertyBlock size

        return node_memory + edge_memory + embedding_memory + property_memory;
    }

    // =============================================================================
    // Compile-Time Configuration Generation
    // =============================================================================

    pub fn generateConfig(self: *const MemoryPredictor, writer: anytype) !void {
        try writer.print("// Generated NenDB Configuration\n");
        try writer.print("// Profile: {s}, Workload: {s}\n", .{ @tagName(self.profile), @tagName(self.workload) });
        try writer.print("// Expected: {} nodes, {} edges, {d:.1f} avg degree\n", .{ self.expected_nodes, self.expected_edges, self.avg_degree });
        try writer.print("// Memory estimate: {d:.1f} MB\n\n", .{@as(f64, @floatFromInt(self.estimateTotalMemory())) / 1024.0 / 1024.0});

        try writer.print("pub const NENDB_NODE_POOL_SIZE = {};\n", .{self.predictNodePoolSize()});
        try writer.print("pub const NENDB_EDGE_POOL_SIZE = {};\n", .{self.predictEdgePoolSize()});
        try writer.print("pub const NENDB_EMBEDDING_POOL_SIZE = {};\n", .{self.predictEmbeddingPoolSize()});
        try writer.print("pub const NENDB_PROPERTY_POOL_SIZE = {};\n", .{self.predictPropertyPoolSize()});
        try writer.print("pub const NENDB_EMBEDDING_DIMENSIONS = {};\n", .{self.embedding_dims});
    }

    // =============================================================================
    // Validation and Safety Checks
    // =============================================================================

    pub fn validateMemoryRequirements(self: *const MemoryPredictor, available_memory_mb: u64) bool {
        const required_memory_mb = self.estimateTotalMemory() / 1024 / 1024;
        return required_memory_mb <= available_memory_mb;
    }

    pub fn getMemoryUtilization(self: *const MemoryPredictor) f32 {
        const total_memory = self.estimateTotalMemory();
        const base_memory = (self.expected_nodes * (8 + 1 + 1 + 4 + 64)) +
            (self.expected_edges * (8 + 8 + 2 + 1 + 4 + 64)) +
            (self.expected_nodes * self.embedding_ratio * (8 + self.embedding_dims * 4 + 1));

        return @as(f32, @floatFromInt(base_memory)) / @as(f32, @floatFromInt(total_memory));
    }
};

// =============================================================================
// Predefined Configurations for Common Use Cases
// =============================================================================

pub const PresetConfigs = struct {
    pub const SOCIAL_NETWORK_SMALL = MemoryPredictor.init(100_000, 500_000, .sparse, .social_network, 128);
    pub const SOCIAL_NETWORK_LARGE = MemoryPredictor.init(1_000_000, 10_000_000, .sparse, .social_network, 128);

    pub const KNOWLEDGE_GRAPH_SMALL = MemoryPredictor.init(50_000, 500_000, .medium, .knowledge_graph, 256);
    pub const KNOWLEDGE_GRAPH_LARGE = MemoryPredictor.init(500_000, 5_000_000, .medium, .knowledge_graph, 256);

    pub const AI_TRAINING_SMALL = MemoryPredictor.init(100_000, 1_000_000, .dense, .ai_training, 768);
    pub const AI_TRAINING_LARGE = MemoryPredictor.init(1_000_000, 10_000_000, .dense, .ai_training, 768);

    pub const RECOMMENDATION_SMALL = MemoryPredictor.init(200_000, 2_000_000, .medium, .recommendation, 512);
    pub const RECOMMENDATION_LARGE = MemoryPredictor.init(2_000_000, 20_000_000, .medium, .recommendation, 512);
};
