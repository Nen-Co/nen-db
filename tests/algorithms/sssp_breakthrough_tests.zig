// NenDB Breakthrough SSSP Algorithm Tests
// Tests for the O(m log^2/3 n) SSSP algorithm implementation

const std = @import("std");
const testing = std.testing;
const nendb = @import("nendb");
const pool = nendb.memory;
const sssp_breakthrough = @import("../../src/algorithms/sssp_breakthrough.zig");

test "SSSP Breakthrough Algorithm - Basic Functionality" {
    // Create a simple test graph
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Add nodes
    const node_a = pool.Node{ .id = 1, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_b = pool.Node{ .id = 2, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_c = pool.Node{ .id = 3, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    
    _ = node_pool.alloc(node_a);
    _ = node_pool.alloc(node_b);
    _ = node_pool.alloc(node_c);
    
    // Add edges: A -> B (weight 5), B -> C (weight 3), A -> C (weight 10)
    const edge_ab = pool.Edge{ .from = 1, .to = 2, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    const edge_bc = pool.Edge{ .from = 2, .to = 3, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    const edge_ac = pool.Edge{ .from = 1, .to = 3, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    
    _ = edge_pool.alloc(edge_ab);
    _ = edge_pool.alloc(edge_bc);
    _ = edge_pool.alloc(edge_ac);
    
    // Custom weight function
    const weight_fn = struct {
        fn weight(edge: pool.Edge) f64 {
            if (edge.from == 1 and edge.to == 2) return 5.0;
            if (edge.from == 2 and edge.to == 3) return 3.0;
            if (edge.from == 1 and edge.to == 3) return 10.0;
            return 1.0; // default weight
        }
    }.weight;
    
    // Execute breakthrough SSSP
    const result = try sssp_breakthrough.BreakthroughSSSP.executeSimple(
        &node_pool,
        &edge_pool,
        1, // source node
        weight_fn,
        testing.allocator,
    );
    defer result.deinit();
    
    // Verify results
    try testing.expect(result.distances[1] == 0.0); // source distance
    try testing.expect(result.distances[2] == 5.0); // A -> B
    try testing.expect(result.distances[3] == 8.0); // A -> B -> C (shorter than A -> C)
    
    // Verify predecessors
    try testing.expect(result.predecessors[1] == 1); // source
    try testing.expect(result.predecessors[2] == 1); // A -> B
    try testing.expect(result.predecessors[3] == 2); // B -> C
    
    // Verify visited nodes
    try testing.expect(result.visited_nodes.len == 3);
    try testing.expect(result.iterations > 0);
}

test "SSSP Breakthrough Algorithm - Path Reconstruction" {
    // Create a test graph
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Add nodes
    const node_a = pool.Node{ .id = 1, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_b = pool.Node{ .id = 2, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_c = pool.Node{ .id = 3, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_d = pool.Node{ .id = 4, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    
    _ = node_pool.alloc(node_a);
    _ = node_pool.alloc(node_b);
    _ = node_pool.alloc(node_c);
    _ = node_pool.alloc(node_d);
    
    // Add edges: A -> B (2), B -> C (3), A -> C (6), C -> D (1)
    const edge_ab = pool.Edge{ .from = 1, .to = 2, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    const edge_bc = pool.Edge{ .from = 2, .to = 3, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    const edge_ac = pool.Edge{ .from = 1, .to = 3, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    const edge_cd = pool.Edge{ .from = 3, .to = 4, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    
    _ = edge_pool.alloc(edge_ab);
    _ = edge_pool.alloc(edge_bc);
    _ = edge_pool.alloc(edge_ac);
    _ = edge_pool.alloc(edge_cd);
    
    // Custom weight function
    const weight_fn = struct {
        fn weight(edge: pool.Edge) f64 {
            if (edge.from == 1 and edge.to == 2) return 2.0;
            if (edge.from == 2 and edge.to == 3) return 3.0;
            if (edge.from == 1 and edge.to == 3) return 6.0;
            if (edge.from == 3 and edge.to == 4) return 1.0;
            return 1.0;
        }
    }.weight;
    
    // Find shortest path from A to D
    const path = try sssp_breakthrough.BreakthroughSSSP.findShortestPath(
        &node_pool,
        &edge_pool,
        1, // source
        4, // target
        null, // no max distance
        weight_fn,
        testing.allocator,
    );
    
    try testing.expect(path != null);
    const path_slice = path.?;
    defer testing.allocator.free(path_slice);
    
    // Verify path: A -> B -> C -> D (total weight 6)
    try testing.expect(path_slice.len == 4);
    try testing.expect(path_slice[0] == 1); // A
    try testing.expect(path_slice[1] == 2); // B
    try testing.expect(path_slice[2] == 3); // C
    try testing.expect(path_slice[3] == 4); // D
}

test "SSSP Breakthrough Algorithm - Unreachable Target" {
    // Create a disconnected graph
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Add nodes
    const node_a = pool.Node{ .id = 1, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_b = pool.Node{ .id = 2, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_c = pool.Node{ .id = 3, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    
    _ = node_pool.alloc(node_a);
    _ = node_pool.alloc(node_b);
    _ = node_pool.alloc(node_c);
    
    // Add only one edge: A -> B
    const edge_ab = pool.Edge{ .from = 1, .to = 2, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    _ = edge_pool.alloc(edge_ab);
    
    // Try to find path from A to C (unreachable)
    const path = try sssp_breakthrough.BreakthroughSSSP.findShortestPath(
        &node_pool,
        &edge_pool,
        1, // source
        3, // target (unreachable)
        null,
        sssp_breakthrough.defaultEdgeWeight,
        testing.allocator,
    );
    
    // Should return null for unreachable target
    try testing.expect(path == null);
}

test "SSSP Breakthrough Algorithm - Large Graph Performance" {
    // Create a larger test graph
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Add 100 nodes
    var i: u64 = 1;
    while (i <= 100) : (i += 1) {
        const node = pool.Node{ .id = i, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
        _ = node_pool.alloc(node);
    }
    
    // Add edges in a chain: 1 -> 2 -> 3 -> ... -> 100
    i = 1;
    while (i < 100) : (i += 1) {
        const edge = pool.Edge{ .from = i, .to = i + 1, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
        _ = edge_pool.alloc(edge);
    }
    
    // Add some cross edges for complexity
    i = 1;
    while (i <= 90) : (i += 10) {
        const edge = pool.Edge{ .from = i, .to = i + 10, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
        _ = edge_pool.alloc(edge);
    }
    
    // Execute breakthrough SSSP
    const result = try sssp_breakthrough.BreakthroughSSSP.executeSimple(
        &node_pool,
        &edge_pool,
        1, // source node
        sssp_breakthrough.defaultEdgeWeight,
        testing.allocator,
    );
    defer result.deinit();
    
    // Verify basic results
    try testing.expect(result.distances[1] == 0.0); // source
    try testing.expect(result.distances[100] < std.math.inf(f64)); // reachable
    try testing.expect(result.visited_nodes.len > 0);
    try testing.expect(result.iterations > 0);
    
    // Verify algorithm completed successfully
    try testing.expect(result.frontier_size >= 0);
}

test "SSSP Breakthrough Algorithm - Frontier Management" {
    // Test frontier functionality
    var frontier = try sssp_breakthrough.Frontier.init(testing.allocator, 10);
    defer frontier.deinit(testing.allocator);
    
    // Add vertices
    try frontier.addVertex(1, 5.0);
    try frontier.addVertex(2, 3.0);
    try frontier.addVertex(3, 7.0);
    try frontier.addVertex(4, 1.0);
    
    try testing.expect(frontier.getSize() == 4);
    try testing.expect(!frontier.isEmpty());
    
    // Extract minimum (should be vertex 4 with distance 1.0)
    const min_vertex = frontier.extractMin();
    try testing.expect(min_vertex == 4);
    try testing.expect(frontier.getSize() == 3);
    
    // Extract next minimum (should be vertex 2 with distance 3.0)
    const next_min = frontier.extractMin();
    try testing.expect(next_min == 2);
    try testing.expect(frontier.getSize() == 2);
    
    // Extract remaining vertices
    const third = frontier.extractMin();
    const fourth = frontier.extractMin();
    try testing.expect(third == 1);
    try testing.expect(fourth == 3);
    try testing.expect(frontier.isEmpty());
}

test "SSSP Breakthrough Algorithm - Dependency Graph" {
    // Test dependency tracking
    var deps = sssp_breakthrough.DependencyGraph.init(testing.allocator);
    defer deps.deinit();
    
    // Add dependencies
    try deps.addDependency(2, 1); // vertex 2 depends on vertex 1
    try deps.addDependency(3, 1); // vertex 3 depends on vertex 1
    try deps.addDependency(4, 2); // vertex 4 depends on vertex 2
    
    // Get dependencies
    const deps_1 = deps.getDependencies(1);
    try testing.expect(deps_1 != null);
    try testing.expect(deps_1.?.len == 2);
    try testing.expect(deps_1.?[0] == 2 or deps_1.?[0] == 3);
    try testing.expect(deps_1.?[1] == 2 or deps_1.?[1] == 3);
    
    const deps_2 = deps.getDependencies(2);
    try testing.expect(deps_2 != null);
    try testing.expect(deps_2.?.len == 1);
    try testing.expect(deps_2.?[0] == 4);
    
    const deps_3 = deps.getDependencies(3);
    try testing.expect(deps_3 == null); // no dependencies
}

test "SSSP Breakthrough Algorithm - Performance Comparison" {
    // Create a test graph for benchmarking
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Add 50 nodes
    var i: u64 = 1;
    while (i <= 50) : (i += 1) {
        const node = pool.Node{ .id = i, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
        _ = node_pool.alloc(node);
    }
    
    // Add edges in a grid pattern
    i = 1;
    while (i <= 40) : (i += 1) {
        // Horizontal edges
        const edge_h = pool.Edge{ .from = i, .to = i + 1, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
        _ = edge_pool.alloc(edge_h);
        
        // Vertical edges
        if (i <= 30) {
            const edge_v = pool.Edge{ .from = i, .to = i + 10, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
            _ = edge_pool.alloc(edge_v);
        }
    }
    
    // Benchmark both algorithms
    const comparison = try sssp_breakthrough.benchmarkAlgorithms(
        &node_pool,
        &edge_pool,
        1, // source node
        sssp_breakthrough.defaultEdgeWeight,
        testing.allocator,
    );
    
    // Verify benchmark completed
    try testing.expect(comparison.breakthrough_time > 0);
    try testing.expect(comparison.dijkstra_time > 0);
    try testing.expect(comparison.speedup > 0.0);
    try testing.expect(comparison.memory_usage_breakthrough > 0);
    try testing.expect(comparison.memory_usage_dijkstra > 0);
    
    // Print results for verification
    comparison.print();
}

test "SSSP Breakthrough Algorithm - Edge Cases" {
    // Test with empty graph
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Add single node
    const node = pool.Node{ .id = 1, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    _ = node_pool.alloc(node);
    
    // Execute SSSP on single node
    const result = try sssp_breakthrough.BreakthroughSSSP.executeSimple(
        &node_pool,
        &edge_pool,
        1, // source node
        sssp_breakthrough.defaultEdgeWeight,
        testing.allocator,
    );
    defer result.deinit();
    
    // Verify results
    try testing.expect(result.distances[1] == 0.0);
    try testing.expect(result.visited_nodes.len == 1);
    try testing.expect(result.iterations > 0);
    
    // Test with self-loop
    const self_loop = pool.Edge{ .from = 1, .to = 1, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    _ = edge_pool.alloc(self_loop);
    
    const result2 = try sssp_breakthrough.BreakthroughSSSP.executeSimple(
        &node_pool,
        &edge_pool,
        1, // source node
        sssp_breakthrough.defaultEdgeWeight,
        testing.allocator,
    );
    defer result2.deinit();
    
    // Should handle self-loop gracefully
    try testing.expect(result2.distances[1] == 0.0);
}

test "SSSP Breakthrough Algorithm - Options and Constraints" {
    // Create a test graph
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    defer node_pool.deinit();
    defer edge_pool.deinit();
    
    // Add nodes
    const node_a = pool.Node{ .id = 1, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_b = pool.Node{ .id = 2, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    const node_c = pool.Node{ .id = 3, .kind = 1, .reserved = [_]u8{0} ** 7, .props = [_]u8{0} ** 32 };
    
    _ = node_pool.alloc(node_a);
    _ = node_pool.alloc(node_b);
    _ = node_pool.alloc(node_c);
    
    // Add edges: A -> B (5), B -> C (3)
    const edge_ab = pool.Edge{ .from = 1, .to = 2, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    const edge_bc = pool.Edge{ .from = 2, .to = 3, .kind = 1, .reserved = [_]u8{0} ** 6, .props = [_]u8{0} ** 32 };
    
    _ = edge_pool.alloc(edge_ab);
    _ = edge_pool.alloc(edge_bc);
    
    // Custom weight function
    const weight_fn = struct {
        fn weight(edge: pool.Edge) f64 {
            if (edge.from == 1 and edge.to == 2) return 5.0;
            if (edge.from == 2 and edge.to == 3) return 3.0;
            return 1.0;
        }
    }.weight;
    
    // Test with max distance constraint
    const options = sssp_breakthrough.BreakthroughSSSPOptions{
        .max_distance = 4.0, // Should prevent reaching node C
    };
    
    var algorithm = try sssp_breakthrough.BreakthroughSSSP.init(
        &node_pool,
        &edge_pool,
        1, // source
        options,
        weight_fn,
        testing.allocator,
    );
    defer algorithm.deinit();
    
    const result = try algorithm.execute();
    defer result.deinit();
    
    // Node C should not be reachable due to max distance constraint
    try testing.expect(result.distances[1] == 0.0);
    try testing.expect(result.distances[2] == 5.0);
    try testing.expect(result.distances[3] == std.math.inf(f64)); // unreachable due to constraint
}

test "SSSP Breakthrough Algorithm - Memory Management" {
    // Test memory management with large frontier
    var frontier = try sssp_breakthrough.Frontier.init(testing.allocator, 2); // small initial capacity
    defer frontier.deinit(testing.allocator);
    
    // Add more vertices than initial capacity to trigger reallocation
    var i: u64 = 1;
    while (i <= 10) : (i += 1) {
        try frontier.addVertex(i, @as(f64, @floatFromInt(i)));
    }
    
    try testing.expect(frontier.getSize() == 10);
    try testing.expect(frontier.capacity >= 10); // should have expanded
    
    // Extract all vertices
    var extracted: [10]u64 = undefined;
    i = 0;
    while (i < 10) : (i += 1) {
        const vertex = frontier.extractMin();
        try testing.expect(vertex != null);
        extracted[i] = vertex.?;
    }
    
    try testing.expect(frontier.isEmpty());
    
    // Verify vertices were extracted in order (1, 2, 3, ..., 10)
    for (extracted, 1..) |vertex, expected| {
        try testing.expect(vertex == expected);
    }
}
