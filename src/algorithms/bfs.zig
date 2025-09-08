// NenDB BFS (Breadth-First Search) Algorithm
// Optimized for static memory pools, DOD layout, and prefetching

const std = @import("std");
const nendb = @import("nendb");
const pool = nendb.memory;
const dod = nendb.dod;
const prefetch = nendb.prefetch;

pub const BFSResult = struct {
    visited_nodes: []u64,
    distances: []u32,
    predecessors: []u64,
    levels: []u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *BFSResult) void {
        self.allocator.free(self.visited_nodes);
        self.allocator.free(self.distances);
        self.allocator.free(self.predecessors);
        self.allocator.free(self.levels);
    }
};

pub const BFSOptions = struct {
    max_depth: ?u32 = null,
    include_distances: bool = true,
    include_predecessors: bool = true,
    include_levels: bool = true,
    max_nodes: ?usize = null,
    // DOD and prefetching options
    enable_dod: bool = true,
    enable_prefetch: bool = true,
    prefetch_config: ?prefetch.PrefetchConfig = null,
};

/// Breadth-First Search algorithm for graph traversal
/// Uses our static memory pool structure for efficient memory access
pub const BFS = struct {
    const Self = @This();

    /// Execute BFS starting from a given source node
    /// Returns a BFSResult with traversal information
    pub fn execute(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        options: BFSOptions,
        allocator: std.mem.Allocator,
    ) !BFSResult {
        // Use DOD-optimized BFS if enabled
        if (options.enable_dod) {
            return Self.executeDOD(node_pool, edge_pool, source_node_id, options, allocator);
        }

        // Fall back to original implementation
        return Self.executeOriginal(node_pool, edge_pool, source_node_id, options, allocator);
    }

    /// DOD-optimized BFS implementation with prefetching
    pub fn executeDOD(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        options: BFSOptions,
        allocator: std.mem.Allocator,
    ) !BFSResult {
        const max_nodes = options.max_nodes orelse node_pool.getStats().total_allocated;

        // Initialize prefetch system
        const prefetch_config = options.prefetch_config orelse prefetch.PrefetchConfig{};
        var prefetch_system = prefetch.PrefetchSystem.init(prefetch_config);

        // Static result arrays (using stack allocation for small graphs)
        const MAX_STATIC_NODES = 1024;
        var visited_nodes_static: [MAX_STATIC_NODES]u64 = [_]u64{0} ** MAX_STATIC_NODES;
        var distances_static: [MAX_STATIC_NODES]u32 = [_]u32{0} ** MAX_STATIC_NODES;
        var predecessors_static: [MAX_STATIC_NODES]u64 = [_]u64{0} ** MAX_STATIC_NODES;
        var levels_static: [MAX_STATIC_NODES]u32 = [_]u32{0} ** MAX_STATIC_NODES;

        // Use static arrays if possible, otherwise fall back to dynamic
        var visited_nodes: []u64 = if (max_nodes <= MAX_STATIC_NODES)
            visited_nodes_static[0..max_nodes]
        else
            try allocator.alloc(u64, max_nodes);
        var distances: []u32 = if (options.include_distances)
            if (max_nodes <= MAX_STATIC_NODES)
                distances_static[0..max_nodes]
            else
                try allocator.alloc(u32, max_nodes)
        else
            &[_]u32{};
        var predecessors: []u64 = if (options.include_predecessors)
            if (max_nodes <= MAX_STATIC_NODES)
                predecessors_static[0..max_nodes]
            else
                try allocator.alloc(u64, max_nodes)
        else
            &[_]u64{};
        var levels: []u32 = if (options.include_levels)
            if (max_nodes <= MAX_STATIC_NODES)
                levels_static[0..max_nodes]
            else
                try allocator.alloc(u32, max_nodes)
        else
            &[_]u32{};

        // Initialize arrays
        @memset(visited_nodes, 0);
        if (options.include_distances) @memset(distances, std.math.maxInt(u32));
        if (options.include_predecessors) @memset(predecessors, 0);
        if (options.include_levels) @memset(levels, 0);

        // BFS queue using DOD layout
        var current_level = std.ArrayList(u64).initCapacity(allocator, 1024);
        defer current_level.deinit();
        var next_level = std.ArrayList(u64).initCapacity(allocator, 1024);
        defer next_level.deinit();

        var visited_count: usize = 0;
        var current_depth: u32 = 0;

        // Start BFS from source node
        try current_level.append(source_node_id);
        if (options.include_distances) distances[visited_count] = 0;
        if (options.include_levels) levels[visited_count] = 0;
        visited_nodes[visited_count] = source_node_id;
        visited_count += 1;

        // Prefetch initial data
        if (options.enable_prefetch) {
            prefetch_system.prefetchBFS(node_pool, &current_level.items, &next_level.items);
        }

        // BFS traversal with DOD optimization
        while (current_level.items.len > 0 and (options.max_depth == null or current_depth < options.max_depth.?)) {
            // Process current level with prefetching
            for (current_level.items) |node_id| {
                // Prefetch edges for this node
                if (options.enable_prefetch) {
                    prefetch_system.prefetchNodeData(node_pool, node_id, 1, .temporal);
                }

                // Find edges from this node using DOD layout
                const edge_indices = Self.findEdgesFromNodeDOD(edge_pool, node_id);

                // Process edges with SIMD optimization
                for (edge_indices) |edge_idx| {
                    if (edge_idx < edge_pool.getStats().total_allocated) {
                        const dest_node_id = edge_pool.getEdge(edge_idx).?.to;

                        // Check if already visited
                        var already_visited = false;
                        for (visited_nodes[0..visited_count]) |visited_id| {
                            if (visited_id == dest_node_id) {
                                already_visited = true;
                                break;
                            }
                        }

                        if (!already_visited) {
                            // Add to next level
                            try next_level.append(dest_node_id);

                            // Update result arrays
                            if (visited_count < max_nodes) {
                                visited_nodes[visited_count] = dest_node_id;
                                if (options.include_distances) distances[visited_count] = current_depth + 1;
                                if (options.include_predecessors) predecessors[visited_count] = node_id;
                                if (options.include_levels) levels[visited_count] = current_depth + 1;
                                visited_count += 1;
                            }
                        }
                    }
                }
            }

            // Prefetch next level data
            if (options.enable_prefetch and next_level.items.len > 0) {
                prefetch_system.prefetchGraphTraversal(node_pool, &next_level.items, .graph_traversal);
            }

            // Swap levels
            std.mem.swap(std.ArrayList(u64), &current_level, &next_level);
            current_level.clearRetainingCapacity();
            current_depth += 1;
        }

        return BFSResult{
            .visited_nodes = visited_nodes[0..visited_count],
            .distances = if (options.include_distances) distances[0..visited_count] else &[_]u32{},
            .predecessors = if (options.include_predecessors) predecessors[0..visited_count] else &[_]u64{},
            .levels = if (options.include_levels) levels[0..visited_count] else &[_]u32{},
            .allocator = allocator,
        };
    }

    /// DOD-optimized edge finding using SoA layout (static allocation)
    fn findEdgesFromNodeDOD(edge_pool: *const pool.EdgePool, node_id: u64) [64]u32 {
        var edge_indices: [64]u32 = [_]u32{0} ** 64;
        var count: u32 = 0;

        // Use DOD layout for efficient edge traversal
        const stats = edge_pool.getStats();
        for (0..stats.total_allocated) |i| {
            const edge = edge_pool.getEdge(@intCast(i));
            if (edge != null and edge.?.from == node_id and count < 64) {
                edge_indices[count] = @intCast(i);
                count += 1;
            }
        }

        return edge_indices;
    }

    /// Original BFS implementation (fallback)
    pub fn executeOriginal(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        options: BFSOptions,
        allocator: std.mem.Allocator,
    ) !BFSResult {
        const max_nodes = options.max_nodes orelse node_pool.getStats().total_allocated;

        // Initialize result arrays
        var visited_nodes = try allocator.alloc(u64, max_nodes);
        var distances: []u32 = if (options.include_distances)
            try allocator.alloc(u32, max_nodes)
        else
            &[_]u32{};
        var predecessors: []u64 = if (options.include_predecessors)
            try allocator.alloc(u64, max_nodes)
        else
            &[_]u64{};
        var levels: []u32 = if (options.include_levels)
            try allocator.alloc(u32, max_nodes)
        else
            &[_]u32{};

        // Initialize arrays
        if (options.include_distances and distances.len > 0) {
            @memset(distances, std.math.maxInt(u32));
            distances[source_node_id] = 0;
        }
        if (options.include_predecessors and predecessors.len > 0) {
            @memset(predecessors, std.math.maxInt(u64));
            predecessors[source_node_id] = source_node_id; // Self-reference for source
        }
        if (options.include_levels and levels.len > 0) {
            @memset(levels, std.math.maxInt(u32));
            levels[source_node_id] = 0;
        }

        // Use a queue for BFS traversal
        var queue = std.BoundedArray(u64, 10000).init(0) catch {
            return error.QueueOverflow;
        };
        try queue.append(source_node_id);

        var visited_count: usize = 0;
        visited_nodes[visited_count] = source_node_id;
        visited_count += 1;

        var current_level: u32 = 0;
        var nodes_at_current_level: usize = 1;
        var nodes_at_next_level: usize = 0;

        while (queue.len > 0) {
            const current_node_id = queue.orderedRemove(0);

            // Check if we've reached max depth
            if (options.max_depth) |max_depth| {
                if (current_level >= max_depth) {
                    continue;
                }
            }

            // Get current node and its edges
            _ = node_pool.get_by_id(current_node_id) orelse continue;

            // Iterate through all edges from current node
            var edge_iter = edge_pool.iterFromNode(current_node_id);
            while (edge_iter.next()) |edge| {
                const neighbor_id = if (edge.from == current_node_id) edge.to else edge.from;

                // Skip if already visited
                if (isNodeVisited(neighbor_id, visited_nodes[0..visited_count])) {
                    continue;
                }

                // Mark as visited
                if (visited_count < max_nodes) {
                    visited_nodes[visited_count] = neighbor_id;
                    visited_count += 1;
                }

                // Update distances, predecessors, and levels
                if (options.include_distances) {
                    distances[neighbor_id] = distances[current_node_id] + 1;
                }
                if (options.include_predecessors) {
                    predecessors[neighbor_id] = current_node_id;
                }
                if (options.include_levels) {
                    levels[neighbor_id] = current_level + 1;
                }

                // Add to queue for next level
                if (queue.len < queue.capacity()) {
                    queue.append(neighbor_id) catch continue;
                    nodes_at_next_level += 1;
                }
            }

            nodes_at_current_level -= 1;

            // Check if we've finished current level
            if (nodes_at_current_level == 0) {
                current_level += 1;
                nodes_at_current_level = nodes_at_next_level;
                nodes_at_next_level = 0;
            }

            // Check if we've reached max nodes limit
            if (options.max_nodes) |max_nodes_limit| {
                if (visited_count >= max_nodes_limit) {
                    break;
                }
            }
        }

        // Resize arrays to actual visited count
        visited_nodes = try allocator.realloc(visited_nodes, visited_count);
        if (options.include_distances) {
            distances = try allocator.realloc(distances, max_nodes);
        }
        if (options.include_predecessors) {
            predecessors = try allocator.realloc(predecessors, max_nodes);
        }
        if (options.include_levels) {
            levels = try allocator.realloc(levels, max_nodes);
        }

        return BFSResult{
            .visited_nodes = visited_nodes,
            .distances = distances,
            .predecessors = predecessors,
            .levels = levels,
            .allocator = allocator,
        };
    }

    /// Execute BFS with path finding to a specific target node
    /// Returns the shortest path from source to target
    pub fn findPath(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        target_node_id: u64,
        max_depth: ?u32,
        allocator: std.mem.Allocator,
    ) !?[]u64 {
        const options = BFSOptions{
            .max_depth = max_depth,
            .include_distances = true,
            .include_predecessors = true,
            .include_levels = false,
        };

        const result = try execute(node_pool, edge_pool, source_node_id, options, allocator);
        defer result.deinit();

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

    /// Execute BFS to find all nodes within a certain distance
    /// Returns nodes grouped by their distance from source
    pub fn findNodesWithinDistance(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        max_distance: u32,
        allocator: std.mem.Allocator,
    ) ![][]u64 {
        const options = BFSOptions{
            .max_depth = max_distance,
            .include_distances = true,
            .include_predecessors = false,
            .include_levels = false,
        };

        const result = try execute(node_pool, edge_pool, source_node_id, options, allocator);
        defer result.deinit();

        // Group nodes by distance
        var nodes_by_distance = try allocator.alloc([]u32, max_distance + 1);
        var counts = try allocator.alloc(usize, max_distance + 1);
        @memset(counts, 0);

        // Count nodes at each distance
        for (result.visited_nodes) |node_id| {
            const distance = result.distances[node_id];
            if (distance <= max_distance) {
                counts[distance] += 1;
            }
        }

        // Allocate arrays for each distance level
        for (0..max_distance + 1) |distance| {
            nodes_by_distance[distance] = try allocator.alloc(u32, counts[distance]);
            counts[distance] = 0; // Reset for filling
        }

        // Fill arrays with node IDs
        for (result.visited_nodes) |node_id| {
            const distance = result.distances[node_id];
            if (distance <= max_distance) {
                nodes_by_distance[distance][counts[distance]] = node_id;
                counts[distance] += 1;
            }
        }

        return nodes_by_distance;
    }

    /// Check if a node has been visited during BFS
    fn isNodeVisited(node_id: u64, visited_nodes: []const u64) bool {
        for (visited_nodes) |visited_id| {
            if (visited_id == node_id) {
                return true;
            }
        }
        return false;
    }
};

test "BFS algorithm basic functionality" {
    const allocator = std.testing.allocator;

    // Create a simple graph: A -> B -> C, A -> D
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();

    // Add nodes
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 3, .labels = &[_]u32{}, .properties = &[_]u8{} });

    // Add edges
    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 1, .to = 2, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 0, .to = 3, .type = 0, .properties = &[_]u8{} });

    // Test BFS from node A
    const result = try BFS.execute(&node_pool, &edge_pool, 0, .{}, allocator);
    defer result.deinit();

    // Should visit all 4 nodes
    try std.testing.expectEqual(@as(usize, 4), result.visited_nodes.len);

    // Check distances
    try std.testing.expectEqual(@as(u32, 0), result.distances[0]); // A
    try std.testing.expectEqual(@as(u32, 1), result.distances[1]); // B
    try std.testing.expectEqual(@as(u32, 2), result.distances[2]); // C
    try std.testing.expectEqual(@as(u32, 1), result.distances[3]); // D
}

test "BFS path finding" {
    const allocator = std.testing.allocator;

    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();

    // Create a chain: A -> B -> C -> D
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 3, .labels = &[_]u32{}, .properties = &[_]u8{} });

    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 1, .to = 2, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 2, .to = 3, .type = 0, .properties = &[_]u8{} });

    // Find path from A to D
    const path = try BFS.findPath(&node_pool, &edge_pool, 0, 3, null, allocator);
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

test "BFS nodes within distance" {
    const allocator = std.testing.allocator;

    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();

    // Create a star graph: A -> B, A -> C, A -> D
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 3, .labels = &[_]u32{}, .properties = &[_]u8{} });

    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 0, .to = 2, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 0, .to = 3, .type = 0, .properties = &[_]u8{} });

    // Find nodes within distance 1 from A
    const nodes_by_distance = try BFS.findNodesWithinDistance(&node_pool, &edge_pool, 0, 1, allocator);
    defer {
        for (nodes_by_distance) |nodes| {
            allocator.free(nodes);
        }
        allocator.free(nodes_by_distance);
    }

    try std.testing.expectEqual(@as(usize, 2), nodes_by_distance.len); // Distance 0 and 1

    // Distance 0 should have 1 node (A)
    try std.testing.expectEqual(@as(usize, 1), nodes_by_distance[0].len);
    try std.testing.expectEqual(@as(u32, 0), nodes_by_distance[0][0]);

    // Distance 1 should have 3 nodes (B, C, D)
    try std.testing.expectEqual(@as(usize, 3), nodes_by_distance[1].len);
}
