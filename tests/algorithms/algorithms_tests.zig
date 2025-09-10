const std = @import("std");
const test_allocator = std.testing.allocator;

const nendb = @import("nendb");
const sssp_breakthrough = @import("nendb").algorithms.sssp_breakthrough;
const dijkstra = @import("nendb").algorithms.dijkstra;
const pool = @import("nendb").memory;

// Mock edge weight function for testing
fn mockEdgeWeight(edge: pool.Edge) f64 {
    _ = edge;
    return 1.0;
}

const mockEdgeWeightFn: sssp_breakthrough.EdgeWeightFn = &mockEdgeWeight;

test "Benchmark SSSP Breakthrough vs Dijkstra" {
    // This test runs the performance comparison between the two SSSP algorithms.
    // NOTE: This is a functional test to ensure the benchmark runs. For accurate
    // performance metrics, this should be run on a larger, more complex graph
    // in a dedicated benchmarking environment.

    var node_pool = pool.NodePool.init();

    var edge_pool = pool.EdgePool.init();

    // Create a simple graph for the benchmark to run against
    // A --1-- B --1-- C
    const node_a = try node_pool.alloc(.{ .id = 1, .kind = 0, .props = [_]u8{0} ** 128 });
    const node_b = try node_pool.alloc(.{ .id = 2, .kind = 0, .props = [_]u8{0} ** 128 });
    const node_c = try node_pool.alloc(.{ .id = 3, .kind = 0, .props = [_]u8{0} ** 128 });

    _ = try edge_pool.alloc(.{ .from = node_a, .to = node_b, .label = 0, .props = [_]u8{0} ** 64 });
    _ = try edge_pool.alloc(.{ .from = node_b, .to = node_c, .label = 0, .props = [_]u8{0} ** 64 });

    // Run the benchmark comparison function
    const comparison = try sssp_breakthrough.benchmarkAlgorithms(
        &node_pool,
        &edge_pool,
        node_a,
        mockEdgeWeightFn,
        test_allocator,
    );

    // Print the results to the console
    comparison.print();

    // We expect the breakthrough algorithm to be faster, but for such a small graph,
    // we'll just assert that the times are greater than zero.
    try std.testing.expect(comparison.breakthrough_time > 0);
    try std.testing.expect(comparison.dijkstra_time > 0);
}
