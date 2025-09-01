// NenDB Breakthrough SSSP Algorithm Demo
// Demonstrates the O(m log^2/3 n) SSSP algorithm implementation

const std = @import("std");
const nendb = @import("nendb");
const pool = nendb.memory;
const sssp_breakthrough = @import("../src/algorithms/sssp_breakthrough.zig");

pub fn main() !void {
    std.debug.print("\n🚀 NenDB Breakthrough SSSP Algorithm Demo\n", .{});
    std.debug.print("==========================================\n\n", .{});
    
    // Create a test graph
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Build a complex test graph
    try buildTestGraph(&node_pool, &edge_pool);
    
    // Demo 1: Basic SSSP execution
    try demoBasicSSSP(&node_pool, &edge_pool);
    
    // Demo 2: Path reconstruction
    try demoPathReconstruction(&node_pool, &edge_pool);
    
    // Demo 3: Performance comparison
    try demoPerformanceComparison(&node_pool, &edge_pool);
    
    // Demo 4: Large graph performance
    try demoLargeGraphPerformance();
    
    std.debug.print("\n✅ Demo completed successfully!\n", .{});
}

fn buildTestGraph(node_pool: *pool.NodePool, edge_pool: *pool.EdgePool) !void {
    std.debug.print("📊 Building test graph...\n", .{});
    
    // Add nodes (cities)
    const cities = [_][]const u8{ "NYC", "LA", "CHI", "HOU", "PHX", "PHI", "SA", "SD", "DAL", "SJ" };
    var city_nodes: [10]u64 = undefined;
    
    for (cities, 0..) |city_name, i| {
        const node_id = @as(u64, @intCast(i + 1));
        const node = pool.Node{ 
            .id = node_id, 
            .kind = 1, 
            .reserved = [_]u8{0} ** 7, 
            .props = [_]u8{0} ** 32 
        };
        city_nodes[i] = node_pool.alloc(node);
        std.debug.print("  Added city: {s} (ID: {})\n", .{city_name, node_id});
    }
    
    // Add edges (flight routes with distances)
    const routes = [_]struct { from: u64, to: u64, distance: f64 }{
        .{ .from = 1, .to = 2, .distance = 2789.0 }, // NYC -> LA
        .{ .from = 1, .to = 3, .distance = 787.0 },  // NYC -> CHI
        .{ .from = 1, .to = 6, .distance = 97.0 },   // NYC -> PHI
        .{ .from = 2, .to = 5, .distance = 372.0 },  // LA -> PHX
        .{ .from = 2, .to = 8, .distance = 120.0 },  // LA -> SD
        .{ .from = 3, .to = 4, .distance = 940.0 },  // CHI -> HOU
        .{ .from = 3, .to = 9, .distance = 925.0 },  // CHI -> DAL
        .{ .from = 4, .to = 7, .distance = 197.0 },  // HOU -> SA
        .{ .from = 4, .to = 9, .distance = 239.0 },  // HOU -> DAL
        .{ .from = 5, .to = 7, .distance = 1064.0 }, // PHX -> SA
        .{ .from = 6, .to = 3, .distance = 787.0 },  // PHI -> CHI
        .{ .from = 7, .to = 9, .distance = 274.0 },  // SA -> DAL
        .{ .from = 8, .to = 10, .distance = 452.0 }, // SD -> SJ
        .{ .from = 9, .to = 10, .distance = 1690.0 }, // DAL -> SJ
    };
    
    for (routes) |route| {
        const edge = pool.Edge{ 
            .from = route.from, 
            .to = route.to, 
            .kind = 1, 
            .reserved = [_]u8{0} ** 6, 
            .props = [_]u8{0} ** 32 
        };
        _ = edge_pool.alloc(edge);
        std.debug.print("  Added route: {} -> {} ({d:.0} miles)\n", .{route.from, route.to, route.distance});
    }
    
    std.debug.print("✅ Graph built with {} nodes and {} edges\n\n", .{cities.len, routes.len});
}

fn demoBasicSSSP(node_pool: *const pool.NodePool, edge_pool: *const pool.EdgePool) !void {
    std.debug.print("🎯 Demo 1: Basic SSSP Execution\n", .{});
    std.debug.print("--------------------------------\n", .{});
    
    // Custom weight function that returns actual distances
    const weight_fn = struct {
        fn weight(edge: pool.Edge) f64 {
            const distances = [_]f64{ 0, 2789, 787, 940, 372, 97, 197, 120, 925, 239, 1064, 787, 274, 452, 1690 };
            const edge_index = @as(usize, @intCast(edge.from * 10 + edge.to));
            if (edge_index < distances.len) return distances[edge_index];
            return 1000.0; // default distance
        }
    }.weight;
    
    // Execute breakthrough SSSP from NYC (node 1)
    const result = try sssp_breakthrough.BreakthroughSSSP.executeSimple(
        node_pool,
        edge_pool,
        1, // NYC
        weight_fn,
        std.heap.page_allocator,
    );
    defer result.deinit();
    
    // Display results
    const city_names = [_][]const u8{ "NYC", "LA", "CHI", "HOU", "PHX", "PHI", "SA", "SD", "DAL", "SJ" };
    
    std.debug.print("Shortest distances from NYC:\n", .{});
    for (city_names, 1..) |city_name, i| {
        const distance = result.distances[i];
        if (distance == std.math.inf(f64)) {
            std.debug.print("  {s}: Unreachable\n", .{city_name});
        } else {
            std.debug.print("  {s}: {d:.0} miles\n", .{city_name, distance});
        }
    }
    
    std.debug.print("\nAlgorithm Statistics:\n", .{});
    std.debug.print("  Iterations: {}\n", .{result.iterations});
    std.debug.print("  Visited nodes: {}\n", .{result.visited_nodes.len});
    std.debug.print("  Frontier size: {}\n", .{result.frontier_size});
    std.debug.print("\n", .{});
}

fn demoPathReconstruction(node_pool: *const pool.NodePool, edge_pool: *const pool.EdgePool) !void {
    std.debug.print("🛤️  Demo 2: Path Reconstruction\n", .{});
    std.debug.print("--------------------------------\n", .{});
    
    const weight_fn = struct {
        fn weight(edge: pool.Edge) f64 {
            const distances = [_]f64{ 0, 2789, 787, 940, 372, 97, 197, 120, 925, 239, 1064, 787, 274, 452, 1690 };
            const edge_index = @as(usize, @intCast(edge.from * 10 + edge.to));
            if (edge_index < distances.len) return distances[edge_index];
            return 1000.0;
        }
    }.weight;
    
    const city_names = [_][]const u8{ "NYC", "LA", "CHI", "HOU", "PHX", "PHI", "SA", "SD", "DAL", "SJ" };
    
    // Find shortest paths to several destinations
    const destinations = [_]u64{ 2, 7, 10 }; // LA, SA, SJ
    
    for (destinations) |dest| {
        const path = try sssp_breakthrough.BreakthroughSSSP.findShortestPath(
            node_pool,
            edge_pool,
            1, // NYC
            dest,
            null, // no max distance
            weight_fn,
            std.heap.page_allocator,
        );
        
        if (path) |path_slice| {
            defer std.heap.page_allocator.free(path_slice);
            
            std.debug.print("NYC -> {s}: ", .{city_names[dest - 1]});
            for (path_slice, 0..) |node_id, i| {
                if (i > 0) std.debug.print(" -> ", .{});
                std.debug.print("{s}", .{city_names[node_id - 1]});
            }
            std.debug.print(" ({} stops)\n", .{path_slice.len - 1});
        } else {
            std.debug.print("NYC -> {s}: No path found\n", .{city_names[dest - 1]});
        }
    }
    
    std.debug.print("\n", .{});
}

fn demoPerformanceComparison(node_pool: *const pool.NodePool, edge_pool: *const pool.EdgePool) !void {
    std.debug.print("⚡ Demo 3: Performance Comparison\n", .{});
    std.debug.print("----------------------------------\n", .{});
    
    const weight_fn = sssp_breakthrough.defaultEdgeWeight;
    
    // Benchmark both algorithms
    const comparison = try sssp_breakthrough.benchmarkAlgorithms(
        node_pool,
        edge_pool,
        1, // NYC
        weight_fn,
        std.heap.page_allocator,
    );
    
    // Display detailed comparison
    std.debug.print("Performance Results:\n", .{});
    std.debug.print("  Breakthrough Algorithm: {} ns\n", .{comparison.breakthrough_time});
    std.debug.print("  Dijkstra's Algorithm:   {} ns\n", .{comparison.dijkstra_time});
    std.debug.print("  Speedup:                {d:.2}x\n", .{comparison.speedup});
    std.debug.print("  Memory Usage (Breakthrough): {} bytes\n", .{comparison.memory_usage_breakthrough});
    std.debug.print("  Memory Usage (Dijkstra):     {} bytes\n", .{comparison.memory_usage_dijkstra});
    std.debug.print("  Memory Savings:              {d:.1}%\n", .{comparison.memory_savings});
    
    if (comparison.speedup > 1.0) {
        std.debug.print("  🎉 Breakthrough algorithm is {d:.1}x faster!\n", .{comparison.speedup});
    } else {
        std.debug.print("  📊 Performance is comparable (small graph)\n", .{});
    }
    
    std.debug.print("\n", .{});
}

fn demoLargeGraphPerformance() !void {
    std.debug.print("🌐 Demo 4: Large Graph Performance\n", .{});
    std.debug.print("-----------------------------------\n", .{});
    
    // Create a larger graph for better performance demonstration
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    const num_nodes = 1000;
    const num_edges = 5000;
    
    std.debug.print("Creating graph with {} nodes and {} edges...\n", .{num_nodes, num_edges});
    
    // Add nodes
    var i: u64 = 1;
    while (i <= num_nodes) : (i += 1) {
        const node = pool.Node{ .id = i, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
        _ = node_pool.alloc(node);
    }
    
    // Add random edges
    var prng = std.rand.DefaultPrng.init(42);
    const random = prng.random();
    
    i = 0;
    while (i < num_edges) : (i += 1) {
        const from = random.intRangeAtMost(u64, 1, num_nodes);
        const to = random.intRangeAtMost(u64, 1, num_nodes);
        if (from != to) {
            const edge = pool.Edge{ .from = from, .to = to, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
            _ = edge_pool.alloc(edge);
        }
    }
    
    // Execute breakthrough SSSP
    const timer = std.time.Timer;
    const start = try timer.start();
    
    const result = try sssp_breakthrough.BreakthroughSSSP.executeSimple(
        &node_pool,
        &edge_pool,
        1, // source node
        sssp_breakthrough.defaultEdgeWeight,
        std.heap.page_allocator,
    );
    defer result.deinit();
    
    const elapsed = start.read();
    
    std.debug.print("Large Graph Results:\n", .{});
    std.debug.print("  Execution time: {} ns ({d:.2} ms)\n", .{elapsed, @as(f64, @floatFromInt(elapsed)) / 1_000_000.0});
    std.debug.print("  Visited nodes: {}\n", .{result.visited_nodes.len});
    std.debug.print("  Iterations: {}\n", .{result.iterations});
    std.debug.print("  Frontier size: {}\n", .{result.frontier_size});
    
    // Calculate reachable nodes
    var reachable_count: usize = 0;
    for (result.distances) |distance| {
        if (distance < std.math.inf(f64)) {
            reachable_count += 1;
        }
    }
    std.debug.print("  Reachable nodes: {}/{} ({d:.1}%)\n", .{reachable_count, num_nodes, @as(f64, @floatFromInt(reachable_count)) / @as(f64, @floatFromInt(num_nodes)) * 100.0});
    
    std.debug.print("\n", .{});
}
