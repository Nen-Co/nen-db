// NenDB Algorithms Demo
// Demonstrates BFS, Dijkstra, and PageRank algorithms

const std = @import("std");
const nendb = @import("nendb");
const algorithms = @import("algorithms");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("🚀 NenDB Algorithms Demo\n", .{});
    try stdout.print("========================\n\n", .{});

    // Initialize GraphDB
    var db: nendb.GraphDB = undefined;
    try db.init_inplace();
    defer db.deinit();

    try stdout.print("📊 Creating sample graph...\n", .{});

    // Create a sample social network graph
    // Users: Alice, Bob, Charlie, David, Eve, Frank
    // Relationships: follows, likes, shares
    _ = try db.insert_node(.{ .id = 0, .kind = 1, .props = [_]u8{0} ** 128 });
    _ = try db.insert_node(.{ .id = 1, .kind = 1, .props = [_]u8{0} ** 128 });
    _ = try db.insert_node(.{ .id = 2, .kind = 1, .props = [_]u8{0} ** 128 });
    _ = try db.insert_node(.{ .id = 3, .kind = 1, .props = [_]u8{0} ** 128 });
    _ = try db.insert_node(.{ .id = 4, .kind = 1, .props = [_]u8{0} ** 128 });
    _ = try db.insert_node(.{ .id = 5, .kind = 1, .props = [_]u8{0} ** 128 });

    // Create relationships with weights
    _ = try db.insert_edge(.{ .from = 0, .to = 1, .label = 0, .props = [_]u8{0} ** 64 }); // Alice -> Bob
    _ = try db.insert_edge(.{ .from = 0, .to = 2, .label = 0, .props = [_]u8{0} ** 64 }); // Alice -> Charlie
    _ = try db.insert_edge(.{ .from = 1, .to = 2, .label = 0, .props = [_]u8{0} ** 64 }); // Bob -> Charlie
    _ = try db.insert_edge(.{ .from = 1, .to = 3, .label = 0, .props = [_]u8{0} ** 64 }); // Bob -> David
    _ = try db.insert_edge(.{ .from = 2, .to = 4, .label = 0, .props = [_]u8{0} ** 64 }); // Charlie -> Eve
    _ = try db.insert_edge(.{ .from = 3, .to = 4, .label = 0, .props = [_]u8{0} ** 64 }); // David -> Eve
    _ = try db.insert_edge(.{ .from = 4, .to = 5, .label = 0, .props = [_]u8{0} ** 64 }); // Eve -> Frank
    _ = try db.insert_edge(.{ .from = 5, .to = 0, .label = 0, .props = [_]u8{0} ** 64 }); // Frank -> Alice (creates cycle)

    try stdout.print("✅ Graph created with {d} nodes and {d} edges\n\n", .{ 6, 8 });

    // Demo 1: BFS Traversal
    try stdout.print("🔍 Demo 1: BFS Traversal from Alice\n", .{});
    try stdout.print("----------------------------------------\n", .{});
    
    const bfs_result = try algorithms.AlgorithmExecutor.executeDefault(
        .bfs,
        &db.node_pool,
        &db.edge_pool,
        0, // Start from Alice
        std.heap.page_allocator,
    );
    defer algorithms.AlgorithmExecutor.deinitResult(bfs_result);

    try stdout.print("BFS visited {d} nodes:\n", .{bfs_result.bfs.visited_nodes.len});
    for (bfs_result.bfs.visited_nodes, 0..) |node_id, i| {
        try stdout.print("  {d}. Node {d} (distance: {d})\n", .{ i + 1, node_id, bfs_result.bfs.distances[node_id] });
    }
    try stdout.print("\n", .{});

    // Demo 2: Dijkstra's Shortest Path
    try stdout.print("🛤️  Demo 2: Dijkstra's Shortest Path\n", .{});
    try stdout.print("----------------------------------------\n", .{});
    
    // Custom weight function based on edge properties
    const weight_fn = struct {
        fn getWeight(edge: nendb.Edge) u32 {
            const props = edge.props[0..];
            if (std.mem.eql(u8, props, "follows")) return 1;
            if (std.mem.eql(u8, props, "likes")) return 2;
            if (std.mem.eql(u8, props, "shares")) return 3;
            return 1; // default weight
        }
    }.getWeight;

    const dijkstra_result = try algorithms.AlgorithmExecutor.executeDijkstraWithWeights(
        &db.node_pool,
        &db.edge_pool,
        0, // Start from Alice
        .{},
        weight_fn,
        std.heap.page_allocator,
    );
    defer algorithms.AlgorithmExecutor.deinitResult(dijkstra_result);

    try stdout.print("Shortest paths from Node 0:\n", .{});
    for (0..6) |node_id| {
        const distance = dijkstra_result.dijkstra.distances[node_id];
        if (distance == std.math.maxInt(u32)) {
            try stdout.print("  Node {d}: unreachable\n", .{node_id});
        } else {
            try stdout.print("  Node {d}: {d} steps\n", .{ node_id, distance });
        }
    }
    try stdout.print("\n", .{});

    // Demo 3: PageRank Centrality
    try stdout.print("📈 Demo 3: PageRank Centrality Analysis\n", .{});
    try stdout.print("----------------------------------------\n", .{});
    
    const pagerank_result = try algorithms.AlgorithmExecutor.executeDefault(
        .pagerank,
        &db.node_pool,
        &db.edge_pool,
        null,
        std.heap.page_allocator,
    );
    defer algorithms.AlgorithmExecutor.deinitResult(pagerank_result);

    try stdout.print("PageRank scores (converged in {d} iterations):\n", .{pagerank_result.pagerank.iterations});
    
    // Get top nodes by PageRank
    const top_nodes = try algorithms.AlgorithmExecutor.getTopPageRankNodes(&pagerank_result.pagerank, 6, std.heap.page_allocator);
    defer std.heap.page_allocator.free(top_nodes);

    for (top_nodes, 0..) |node_id, i| {
        const score = pagerank_result.pagerank.scores[node_id];
        try stdout.print("  {d}. Node {d}: {d:.4}\n", .{ i + 1, node_id, score });
    }
    try stdout.print("\n", .{});

    // Demo 4: Graph Analysis
    try stdout.print("📊 Demo 4: Graph Analysis\n", .{});
    try stdout.print("---------------------------\n", .{});
    
    const is_connected = try algorithms.AlgorithmUtils.isGraphConnected(&db.node_pool, &db.edge_pool, std.heap.page_allocator);
    const diameter = try algorithms.AlgorithmUtils.getGraphDiameter(&db.node_pool, &db.edge_pool, std.heap.page_allocator);
    const avg_path_length = try algorithms.AlgorithmUtils.getAverageShortestPathLength(&db.node_pool, &db.edge_pool, std.heap.page_allocator);
    const density = algorithms.AlgorithmUtils.getGraphDensity(&db.node_pool, &db.edge_pool);

    try stdout.print("Graph Properties:\n", .{});
    try stdout.print("  Connected: {s}\n", .{if (is_connected) "Yes" else "No"});
    try stdout.print("  Diameter: {d}\n", .{diameter});
    try stdout.print("  Average Path Length: {d:.2}\n", .{avg_path_length});
    try stdout.print("  Density: {d:.4}\n", .{density});
    try stdout.print("\n", .{});

    // Demo 5: Path Finding
    try stdout.print("🎯 Demo 5: Path Finding\n", .{});
    try stdout.print("------------------------\n", .{});
    
    // Find shortest path from Node 0 to Node 5
    const path = try algorithms.AlgorithmExecutor.findShortestPath(
        &db.node_pool,
        &db.edge_pool,
        0, // Node 0
        5, // Node 5
        null, // no max distance
        weight_fn,
        std.heap.page_allocator,
    );
    defer if (path) |p| std.heap.page_allocator.free(p);

    if (path) |p| {
        try stdout.print("Shortest path from Node 0 to Node 5:\n", .{});
        for (p, 0..) |node_id, i| {
            if (i == 0) {
                try stdout.print("  Node {d}", .{node_id});
            } else {
                try stdout.print(" -> Node {d}", .{node_id});
            }
        }
        try stdout.print(" (length: {d})\n", .{p.len - 1});
    } else {
        try stdout.print("No path found from Node 0 to Node 5\n", .{});
    }

    try stdout.print("\n🎉 Algorithm demo completed successfully!\n", .{});
}
