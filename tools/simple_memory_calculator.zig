// Simple Memory Calculator for NenDB
// Calculates memory requirements for different graph workloads

const std = @import("std");

const GraphProfile = enum {
    sparse, // Social network: 2-10 edges per node
    medium, // Knowledge graph: 10-50 edges per node
    dense, // Dense graph: 50-200 edges per node
    hyper_dense, // Mesh network: 200+ edges per node
    ai_workload, // AI/ML: High embedding usage
};

const WorkloadType = enum {
    social_network, // Facebook, Twitter-like
    knowledge_graph, // Wikipedia, Wikidata-like
    recommendation, // E-commerce, content recommendation
    ai_training, // ML model training
    real_time_analytics, // Live data processing
    batch_processing, // ETL, data warehousing
};

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 6) {
        std.debug.print("Usage: {s} <nodes> <edges> <profile> <workload> <embedding_dims>\n", .{args[0]});
        std.debug.print("Profiles: sparse, medium, dense, hyper_dense, ai_workload\n", .{});
        std.debug.print("Workloads: social_network, knowledge_graph, recommendation, ai_training, real_time_analytics, batch_processing\n", .{});
        std.debug.print("Examples:\n", .{});
        std.debug.print("  {s} 100000 500000 sparse social_network 128\n", .{args[0]});
        std.debug.print("  {s} 1000000 10000000 medium knowledge_graph 256\n", .{args[0]});
        std.debug.print("  {s} 500000 5000000 dense ai_training 768\n", .{args[0]});
        return;
    }

    const nodes = try std.fmt.parseInt(u32, args[1], 10);
    const edges = try std.fmt.parseInt(u32, args[2], 10);
    const profile_str = args[3];
    const workload_str = args[4];
    const embedding_dims = try std.fmt.parseInt(u32, args[5], 10);

    _ = std.meta.stringToEnum(GraphProfile, profile_str) orelse {
        std.debug.print("Error: Invalid profile '{s}'\n", .{profile_str});
        return;
    };

    const workload = std.meta.stringToEnum(WorkloadType, workload_str) orelse {
        std.debug.print("Error: Invalid workload '{s}'\n", .{workload_str});
        return;
    };

    // Calculate memory requirements
    const avg_degree = if (nodes > 0) @as(f32, @floatFromInt(edges)) / @as(f32, @floatFromInt(nodes)) else 0.0;

    // Safety margins
    const safety_margin = 1.5; // 50% safety margin
    const growth_factor = 2.0; // 2x growth capacity

    // Calculate pool sizes with safety margins
    const node_pool = std.math.ceilPowerOfTwo(u32, @as(u32, @intFromFloat(@as(f32, @floatFromInt(nodes)) * growth_factor * safety_margin))) catch nodes * 2;
    const edge_pool = std.math.ceilPowerOfTwo(u32, @as(u32, @intFromFloat(@as(f32, @floatFromInt(edges)) * growth_factor * safety_margin))) catch edges * 2;

    // Embedding ratio based on workload
    const embedding_ratio = getEmbeddingRatio(workload);

    const nodes_with_embeddings = @as(u32, @intFromFloat(@as(f32, @floatFromInt(nodes)) * embedding_ratio));
    const embedding_pool = std.math.ceilPowerOfTwo(u32, @as(u32, @intFromFloat(@as(f32, @floatFromInt(nodes_with_embeddings)) * growth_factor * safety_margin))) catch nodes_with_embeddings * 2;

    // Property density based on workload
    const property_density = getPropertyDensity(workload);

    const avg_properties_per_node = 1.0 + (property_density * 10.0); // 1-11 properties
    const total_properties = @as(u32, @intFromFloat(@as(f32, @floatFromInt(nodes)) * avg_properties_per_node));
    const property_pool = std.math.ceilPowerOfTwo(u32, @as(u32, @intFromFloat(@as(f32, @floatFromInt(total_properties)) * growth_factor * safety_margin))) catch total_properties * 2;

    // Calculate memory usage
    const node_memory = @as(u64, node_pool) * (8 + 1 + 1 + 4 + 64); // id + kind + active + generation + properties
    const edge_memory = @as(u64, edge_pool) * (8 + 8 + 2 + 1 + 4 + 64); // from + to + label + active + generation + properties
    const embedding_memory = @as(u64, embedding_pool) * (@as(u64, embedding_dims) * 4 + 8 + 1); // id + vector + active
    const property_memory = @as(u64, property_pool) * 64; // PropertyBlock size

    const total_memory = node_memory + edge_memory + embedding_memory + property_memory;

    // Print results
    std.debug.print("NenDB Memory Configuration for {s} {s} workload:\n", .{ profile_str, workload_str });
    std.debug.print("Expected: {} nodes, {} edges, {d:.1} avg degree\n", .{ nodes, edges, avg_degree });
    std.debug.print("Embedding ratio: {d:.1}% ({} nodes)\n", .{ embedding_ratio * 100.0, nodes_with_embeddings });
    std.debug.print("Property density: {d:.1}% (avg {d:.1} properties/node)\n", .{ property_density * 100.0, avg_properties_per_node });
    std.debug.print("\nRecommended pool sizes:\n", .{});
    std.debug.print("  NENDB_NODE_POOL_SIZE = {};\n", .{node_pool});
    std.debug.print("  NENDB_EDGE_POOL_SIZE = {};\n", .{edge_pool});
    std.debug.print("  NENDB_EMBEDDING_POOL_SIZE = {};\n", .{embedding_pool});
    std.debug.print("  NENDB_PROPERTY_POOL_SIZE = {};\n", .{property_pool});
    std.debug.print("  NENDB_EMBEDDING_DIMENSIONS = {};\n", .{embedding_dims});
    std.debug.print("\nMemory allocation:\n", .{});
    std.debug.print("  Nodes: {} ({d:.1} MB)\n", .{ node_pool, @as(f64, @floatFromInt(node_memory)) / 1024.0 / 1024.0 });
    std.debug.print("  Edges: {} ({d:.1} MB)\n", .{ edge_pool, @as(f64, @floatFromInt(edge_memory)) / 1024.0 / 1024.0 });
    std.debug.print("  Embeddings: {} ({d:.1} MB)\n", .{ embedding_pool, @as(f64, @floatFromInt(embedding_memory)) / 1024.0 / 1024.0 });
    std.debug.print("  Properties: {} ({d:.1} MB)\n", .{ property_pool, @as(f64, @floatFromInt(property_memory)) / 1024.0 / 1024.0 });
    std.debug.print("  Total: {d:.1} MB ({d:.2} GB)\n", .{ @as(f64, @floatFromInt(total_memory)) / 1024.0 / 1024.0, @as(f64, @floatFromInt(total_memory)) / 1024.0 / 1024.0 / 1024.0 });

    // Utilization estimate
    const base_memory = (@as(u64, nodes) * (8 + 1 + 1 + 4 + 64)) +
        (@as(u64, edges) * (8 + 8 + 2 + 1 + 4 + 64)) +
        (@as(u64, nodes_with_embeddings) * (@as(u64, embedding_dims) * 4 + 8 + 1));
    const utilization = @as(f32, @floatFromInt(base_memory)) / @as(f32, @floatFromInt(total_memory));
    std.debug.print("  Utilization: {d:.1}%\n", .{utilization * 100.0});
}

fn getEmbeddingRatio(workload: WorkloadType) f32 {
    return switch (workload) {
        .ai_training => 1.0, // All nodes have embeddings
        .recommendation => 0.8, // Most nodes have embeddings
        .social_network => 0.1, // Few embeddings
        .knowledge_graph => 0.3, // Some embeddings
        .real_time_analytics => 0.2,
        .batch_processing => 0.1,
    };
}

fn getPropertyDensity(workload: WorkloadType) f32 {
    return switch (workload) {
        .social_network => 0.1, // Minimal properties
        .knowledge_graph => 0.8, // Rich properties
        .recommendation => 0.3, // Moderate properties
        .ai_training => 0.2, // Focus on embeddings
        .real_time_analytics => 0.1,
        .batch_processing => 0.5,
    };
}
