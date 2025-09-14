// NenDB Data-Oriented Design (DOD) Demo
// Demonstrates the performance benefits of DOD architecture

const std = @import("std");
const nendb = @import("nendb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.debug.print("🚀 NenDB Data-Oriented Design (DOD) Demo\n", .{});
    std.debug.print("=====================================\n\n", .{});

    // Initialize DOD data structures
    var graph_data = nendb.dod.DODGraphData.init();
    var component_system = nendb.dod.ComponentSystem.init();

    // Demo 1: SoA vs AoS Performance
    std.debug.print("📊 Demo 1: Struct of Arrays (SoA) Performance\n", .{});
    std.debug.print("--------------------------------------------\n", .{});

    const num_nodes = 1000;
    const num_edges = 2000;

    // Add nodes using SoA layout
    const start_time = std.time.nanoTimestamp();

    for (0..num_nodes) |i| {
        _ = try graph_data.addNode(@as(u64, @intCast(i)), @as(u8, @intCast(i % 10)));
    }

    for (0..num_edges) |i| {
        const from = @as(u64, @intCast(i % num_nodes));
        const to = @as(u64, @intCast((i + 1) % num_nodes));
        _ = try graph_data.addEdge(from, to, @as(u16, @intCast(i % 5)));
    }

    const end_time = std.time.nanoTimestamp();
    const duration_ns = end_time - start_time;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Added {d} nodes and {d} edges in {d:.2}ms\n", .{ num_nodes, num_edges, duration_ms });
    std.debug.print("⚡ Performance: {d:.0} operations/second\n\n", .{@as(f64, @floatFromInt(num_nodes + num_edges)) / (duration_ms / 1000.0)});

    // Demo 2: SIMD-Optimized Filtering
    std.debug.print("🔍 Demo 2: SIMD-Optimized Filtering\n", .{});
    std.debug.print("-----------------------------------\n", .{});

    var filter_results: [1000]u32 = undefined;

    const filter_start = std.time.nanoTimestamp();
    const filtered_count = nendb.simd.SIMDBatchProcessor.filterNodesByKindSIMD(&graph_data, 5, &filter_results);
    const filter_end = std.time.nanoTimestamp();
    const filter_duration_ns = filter_end - filter_start;
    const filter_duration_ms = @as(f64, @floatFromInt(filter_duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Found {d} nodes of kind 5 in {d:.3}ms\n", .{ filtered_count, filter_duration_ms });
    std.debug.print("⚡ Filtering performance: {d:.0} nodes/second\n\n", .{@as(f64, @floatFromInt(filtered_count)) / (filter_duration_ms / 1000.0)});

    // Demo 3: Component System
    std.debug.print("🧩 Demo 3: Component-Based Architecture\n", .{});
    std.debug.print("---------------------------------------\n", .{});

    // Add some components
    for (0..100) |i| {
        const entity_id = @as(u32, @intCast(i));

        // Add position component
        component_system.positions[entity_id] = nendb.dod.Vec3{
            .x = @as(f32, @floatFromInt(i)),
            .y = @as(f32, @floatFromInt(i * 2)),
            .z = @as(f32, @floatFromInt(i * 3)),
        };

        // Add embedding component
        var embedding = nendb.dod.EmbeddingVector.init();
        for (0..nendb.constants.data.embedding_dimensions) |j| {
            embedding.vector[j] = @as(f32, @floatFromInt(i + j));
        }
        component_system.embeddings[entity_id] = embedding;

        // Set component mask
        component_system.component_masks[entity_id].setComponent(.position);
        component_system.component_masks[entity_id].setComponent(.embedding);
    }

    // Filter by component type
    var component_results: [100]u32 = undefined;
    const component_count = component_system.filterByComponent(.position, &component_results);

    std.debug.print("✅ Found {d} entities with position component\n", .{component_count});
    std.debug.print("✅ Found {d} entities with embedding component\n", .{component_system.filterByComponent(.embedding, &component_results)});

    // Demo 4: SIMD Vector Operations
    std.debug.print("\n🔢 Demo 4: SIMD Vector Operations\n", .{});
    std.debug.print("---------------------------------\n", .{});

    // Create test embeddings
    var embedding1: [nendb.constants.data.embedding_dimensions]f32 = undefined;
    var embedding2: [nendb.constants.data.embedding_dimensions]f32 = undefined;

    for (0..nendb.constants.data.embedding_dimensions) |i| {
        embedding1[i] = @as(f32, @floatFromInt(i));
        embedding2[i] = @as(f32, @floatFromInt(i + 1));
    }

    const simd_start = std.time.nanoTimestamp();
    const similarity = nendb.simd.SIMDBatchProcessor.computeEmbeddingSimilaritySIMD(embedding1, embedding2);
    const simd_end = std.time.nanoTimestamp();
    const simd_duration_ns = simd_end - simd_start;
    const simd_duration_ms = @as(f64, @floatFromInt(simd_duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Computed embedding similarity: {d:.4}\n", .{similarity});
    std.debug.print("⚡ SIMD computation time: {d:.3}ms\n", .{simd_duration_ms});

    // Demo 5: Memory Statistics
    std.debug.print("\n📈 Demo 5: Memory Statistics\n", .{});
    std.debug.print("----------------------------\n", .{});

    const stats = graph_data.getStats();
    std.debug.print("📊 Graph Data Statistics:\n", .{});
    std.debug.print("   Nodes: {d}/{d} ({d:.1}% utilization)\n", .{ stats.node_count, stats.node_capacity, (@as(f64, @floatFromInt(stats.node_count)) / @as(f64, @floatFromInt(stats.node_capacity))) * 100.0 });
    std.debug.print("   Edges: {d}/{d} ({d:.1}% utilization)\n", .{ stats.edge_count, stats.edge_capacity, (@as(f64, @floatFromInt(stats.edge_count)) / @as(f64, @floatFromInt(stats.edge_capacity))) * 100.0 });
    std.debug.print("   Embeddings: {d}/{d} ({d:.1}% utilization)\n", .{ stats.embedding_count, stats.embedding_capacity, (@as(f64, @floatFromInt(stats.embedding_count)) / @as(f64, @floatFromInt(stats.embedding_capacity))) * 100.0 });
    std.debug.print("   Overall utilization: {d:.1}%\n", .{stats.getUtilization() * 100.0});

    // Demo 6: DOD Benefits Summary
    std.debug.print("\n🎯 DOD Benefits Demonstrated\n", .{});
    std.debug.print("----------------------------\n", .{});
    std.debug.print("✅ Struct of Arrays (SoA) layout for better cache locality\n", .{});
    std.debug.print("✅ SIMD-optimized operations for vectorized processing\n", .{});
    std.debug.print("✅ Component-based architecture for flexible data modeling\n", .{});
    std.debug.print("✅ Hot/cold data separation for optimal memory usage\n", .{});
    std.debug.print("✅ Static memory allocation for predictable performance\n", .{});
    std.debug.print("✅ Batch processing for maximum throughput\n", .{});

    std.debug.print("\n🚀 NenDB DOD architecture delivers maximum performance!\n", .{});
}
