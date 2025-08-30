// NenDB Dijkstra's Shortest Path Algorithm
// Optimized for static memory pools and efficient path finding

const std = @import("std");
const nendb = @import("nendb");
const pool = nendb.memory;

pub const DijkstraResult = struct {
    distances: []u32,
    predecessors: []u64,
    visited_nodes: []u64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DijkstraResult) void {
        self.allocator.free(self.distances);
        self.allocator.free(self.predecessors);
        self.allocator.free(self.visited_nodes);
    }
};

pub const DijkstraOptions = struct {
    max_distance: ?u32 = null,
    include_predecessors: bool = true,
    include_visited: bool = true,
    max_nodes: ?usize = null,
};

/// Edge weight function type - returns weight for a given edge
pub const EdgeWeightFn = fn (edge: pool.Edge) u32;

/// Default edge weight function - returns 1 for all edges (unweighted)
pub fn defaultEdgeWeight(edge: pool.Edge) u32 {
    _ = edge;
    return 1;
}

/// Dijkstra's shortest path algorithm for weighted graphs
/// Uses our static memory pool structure for efficient memory access
pub const Dijkstra = struct {
    const Self = @This();

    /// Priority queue entry for Dijkstra's algorithm
    const QueueEntry = struct {
        node_id: u64,
        distance: u32,

        pub fn compare(_: void, a: QueueEntry, b: QueueEntry) std.math.Order {
            return std.math.order(a.distance, b.distance);
        }
    };

    /// Execute Dijkstra's algorithm starting from a given source node
    /// Returns a DijkstraResult with shortest path information
    pub fn execute(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        options: DijkstraOptions,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !DijkstraResult {
        const max_nodes = options.max_nodes orelse node_pool.getStats().total_allocated;
        
        // Initialize result arrays
        var distances = try allocator.alloc(u32, max_nodes);
        var predecessors: []u64 = if (options.include_predecessors) 
            try allocator.alloc(u64, max_nodes) else &[_]u64{};
        var visited_nodes: []u64 = if (options.include_visited) 
            try allocator.alloc(u64, max_nodes) else &[_]u64{};

        // Initialize distances to infinity and predecessors to invalid
        @memset(distances, std.math.maxInt(u32));
        distances[source_node_id] = 0;
        
        if (options.include_predecessors and predecessors.len > 0) {
            @memset(predecessors, std.math.maxInt(u64));
            predecessors[source_node_id] = source_node_id; // Self-reference for source
        }

        // Priority queue for Dijkstra's algorithm
        var queue = std.PriorityQueue(QueueEntry, void, QueueEntry.compare).init(allocator, void{});
        defer queue.deinit();
        
        try queue.add(QueueEntry{ .node_id = source_node_id, .distance = 0 });

        var visited_count: usize = 0;
        if (options.include_visited) {
            visited_nodes[visited_count] = source_node_id;
            visited_count += 1;
        }

        while (queue.count() > 0) {
            const current_entry = queue.remove();
            const current_node_id = current_entry.node_id;
            const current_distance = current_entry.distance;

            // Skip if we've already found a shorter path
            if (current_distance > distances[current_node_id]) {
                continue;
            }

            // Check if we've reached max distance
            if (options.max_distance) |max_distance| {
                if (current_distance >= max_distance) {
                    continue;
                }
            }

            // Get current node and iterate through its edges
            _ = node_pool.get_by_id(current_node_id) orelse continue;
            
            var edge_iter = edge_pool.iterFromNode(current_node_id);
            while (edge_iter.next()) |edge| {
                const neighbor_id = if (edge.from == current_node_id) edge.to else edge.from;
                const edge_weight = weight_fn(edge);
                const new_distance = current_distance + edge_weight;

                // Check if this path is shorter than previously found
                if (new_distance < distances[neighbor_id]) {
                    distances[neighbor_id] = new_distance;
                    
                    if (options.include_predecessors) {
                        predecessors[neighbor_id] = current_node_id;
                    }

                    // Add to priority queue
                    try queue.add(QueueEntry{ .node_id = neighbor_id, .distance = new_distance });
                }
            }

            // Mark as visited
            if (options.include_visited and visited_nodes.len > 0) {
                if (visited_count < max_nodes) {
                    visited_nodes[visited_count] = current_node_id;
                    visited_count += 1;
                }
            }

            // Check if we've reached max nodes limit
            if (options.max_nodes) |max_nodes_limit| {
                if (visited_count >= max_nodes_limit) {
                    break;
                }
            }
        }

        // Resize arrays to actual visited count
        if (options.include_visited) {
            visited_nodes = try allocator.realloc(visited_nodes, visited_count);
        }

        return DijkstraResult{
            .distances = distances,
            .predecessors = predecessors,
            .visited_nodes = visited_nodes,
            .allocator = allocator,
        };
    }

    /// Find shortest path from source to a specific target node
    /// Returns the shortest path as an array of node IDs
    pub fn findShortestPath(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        target_node_id: u64,
        max_distance: ?u32,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !?[]u64 {
        const options = DijkstraOptions{
            .max_distance = max_distance,
            .include_predecessors = true,
            .include_visited = false,
        };

        const result = try execute(node_pool, edge_pool, source_node_id, options, weight_fn, allocator);
        defer {
            var mutable_result = result;
            mutable_result.deinit();
        }

        // Check if target was reached
        if (result.distances[target_node_id] == std.math.maxInt(u32)) {
            return null; // Target not reachable
        }

        // Reconstruct path
        const path_length = result.distances[@intCast(target_node_id)] + 1;
        var path = try allocator.alloc(u64, path_length);
        
        var current = target_node_id;
        var path_index = path_length - 1;
        
        while (current != source_node_id) {
            path[path_index] = current;
            current = result.predecessors[@intCast(current)];
            path_index -= 1;
        }
        path[0] = source_node_id;

        return path;
    }

    /// Find all shortest paths from source to all reachable nodes
    /// Returns a map of node ID to shortest path
    pub fn findAllShortestPaths(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        max_distance: ?u32,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !std.AutoHashMap(u64, []u64) {
        const options = DijkstraOptions{
            .max_distance = max_distance,
            .include_predecessors = true,
            .include_visited = true,
        };

        const result = try execute(node_pool, edge_pool, source_node_id, options, weight_fn, allocator);
        defer {
            var mutable_result = result;
            mutable_result.deinit();
        }

        var paths = std.AutoHashMap(u32, []u32).init(allocator);

        // Build paths for all visited nodes
        for (result.visited_nodes) |node_id| {
            if (node_id == source_node_id) {
                // Source node has empty path
                try paths.put(node_id, &[_]u32{});
                continue;
            }

            // Reconstruct path for this node
            const path_length = result.distances[node_id] + 1;
            var path = try allocator.alloc(u32, path_length);
            
            var current = node_id;
            var path_index = path_length - 1;
            
            while (current != source_node_id) {
                path[path_index] = current;
                current = result.predecessors[current];
                path_index -= 1;
            }
            path[0] = source_node_id;

            try paths.put(node_id, path);
        }

        return paths;
    }

    /// Find nodes within a certain distance from source
    /// Returns an array of node IDs that are reachable within max_distance
    pub fn findNodesWithinDistance(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u32,
        max_distance: u32,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) ![]u32 {
        const options = DijkstraOptions{
            .max_distance = max_distance,
            .include_predecessors = false,
            .include_visited = true,
        };

        const result = try execute(node_pool, edge_pool, source_node_id, options, weight_fn, allocator);
        defer {
            var mutable_result = result;
            mutable_result.deinit();
        }

        // Filter nodes within max_distance
        var nodes_within_distance = std.ArrayList(u32).init(allocator);
        defer nodes_within_distance.deinit();

        for (result.visited_nodes) |node_id| {
            if (result.distances[node_id] <= max_distance) {
                try nodes_within_distance.append(node_id);
            }
        }

        return nodes_within_distance.toOwnedSlice();
    }

    /// Check if a path exists between two nodes
    /// Returns true if target is reachable from source
    pub fn hasPath(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u32,
        target_node_id: u32,
        max_distance: ?u32,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !bool {
        const options = DijkstraOptions{
            .max_distance = max_distance,
            .include_predecessors = false,
            .include_visited = false,
        };

        const result = try execute(node_pool, edge_pool, source_node_id, options, weight_fn, allocator);
        defer result.deinit();

        return result.distances[target_node_id] != std.math.maxInt(u32);
    }
};

test "Dijkstra algorithm basic functionality" {
    const allocator = std.testing.allocator;
    
    // Create a simple weighted graph: A --2-- B --3-- C
    //                                |           |
    //                                1           4
    //                                |           |
    //                                D ----------+
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    
    // Add nodes
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 3, .labels = &[_]u32{}, .properties = &[_]u8{} });
    
    // Add weighted edges
    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{2} });
    _ = try edge_pool.alloc(.{ .from = 1, .to = 2, .type = 0, .properties = &[_]u8{3} });
    _ = try edge_pool.alloc(.{ .from = 0, .to = 3, .type = 0, .properties = &[_]u8{1} });
    _ = try edge_pool.alloc(.{ .from = 3, .to = 2, .type = 0, .properties = &[_]u8{4} });
    
    // Custom weight function that reads from edge properties
    const weight_fn = struct {
        fn getWeight(edge: pool.Edge) u32 {
            if (edge.properties.len > 0) {
                return edge.properties[0];
            }
            return 1;
        }
    }.getWeight;
    
    // Test Dijkstra from node A
    const result = try Dijkstra.execute(&node_pool, &edge_pool, 0, .{}, weight_fn, allocator);
    defer result.deinit();
    
    // Check distances
    try std.testing.expectEqual(@as(u32, 0), result.distances[0]); // A: 0
    try std.testing.expectEqual(@as(u32, 2), result.distances[1]); // B: 2
    try std.testing.expectEqual(@as(u32, 5), result.distances[2]); // C: 5 (A->B->C: 2+3)
    try std.testing.expectEqual(@as(u32, 1), result.distances[3]); // D: 1
}

test "Dijkstra shortest path finding" {
    const allocator = std.testing.allocator;
    
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    
    // Create a chain: A --1-- B --2-- C --3-- D
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 3, .labels = &[_]u32{}, .properties = &[_]u8{} });
    
    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{1} });
    _ = try edge_pool.alloc(.{ .from = 1, .to = 2, .type = 0, .properties = &[_]u8{2} });
    _ = try edge_pool.alloc(.{ .from = 2, .to = 3, .type = 0, .properties = &[_]u8{3} });
    
    const weight_fn = struct {
        fn getWeight(edge: pool.Edge) u32 {
            if (edge.properties.len > 0) {
                return edge.properties[0];
            }
            return 1;
        }
    }.getWeight;
    
    // Find shortest path from A to D
    const path = try Dijkstra.findShortestPath(&node_pool, &edge_pool, 0, 3, null, weight_fn, allocator);
    defer if (path) |p| allocator.free(p);
    
    try std.testing.expect(path != null);
    if (path) |p| {
        try std.testing.expectEqual(@as(usize, 4), p.len);
        try std.testing.expectEqual(@as(u32, 0), p[0]); // A
        try std.testing.expectEqual(@as(u32, 1), p[1]); // B
        try std.testing.expectEqual(@as(u32, 2), p[2]); // C
        try std.testing.expectEqual(@as(u32, 3), p[3]); // D
    }
}

test "Dijkstra nodes within distance" {
    const allocator = std.testing.allocator;
    
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    
    // Create a star graph with weights: A --1-- B, A --2-- C, A --3-- D
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 3, .labels = &[_]u32{}, .properties = &[_]u8{} });
    
    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{1} });
    _ = try edge_pool.alloc(.{ .from = 0, .to = 2, .type = 0, .properties = &[_]u8{2} });
    _ = try edge_pool.alloc(.{ .from = 0, .to = 3, .type = 0, .properties = &[_]u8{3} });
    
    const weight_fn = struct {
        fn getWeight(edge: pool.Edge) u32 {
            if (edge.properties.len > 0) {
                return edge.properties[0];
            }
            return 1;
        }
    }.getWeight;
    
    // Find nodes within distance 2 from A
    const nodes_within_distance = try Dijkstra.findNodesWithinDistance(&node_pool, &edge_pool, 0, 2, weight_fn, allocator);
    defer allocator.free(nodes_within_distance);
    
    // Should find A (distance 0), B (distance 1), C (distance 2)
    try std.testing.expectEqual(@as(usize, 3), nodes_within_distance.len);
    
    // Check that D is not included (distance 3 > 2)
    var found_d = false;
    for (nodes_within_distance) |node_id| {
        if (node_id == 3) found_d = true;
    }
    try std.testing.expect(!found_d);
}
