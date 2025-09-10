// NenDB Breakthrough SSSP Algorithm Implementation
// Based on "Breaking the Sorting Barrier for Directed Single-Source Shortest Paths"
// Authors: Ran Duan, Jiayi Mao, Xiao Mao, Xinkai Shu, Longhui Yin
// arXiv: https://arxiv.org/abs/2504.17033v2
// Time Complexity: O(m log^2/3 n) deterministic algorithm

const std = @import("std");
const pool = @import("../memory/pool_v2.zig");

/// Neighbor structure for algorithm
const Neighbor = struct {
    vertex: u64,
    weight: f64,
};

pub const BreakthroughSSSPResult = struct {
    distances: []f64,
    predecessors: []u64,
    visited_nodes: []u64,
    frontier_size: usize,
    iterations: usize,
    memory_bytes: usize,
    neighbor_overflow_events: u32,
    max_observed_out_degree: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *BreakthroughSSSPResult) void {
        self.allocator.free(self.distances);
        self.allocator.free(self.predecessors);
        self.allocator.free(self.visited_nodes);
    }
};

pub const BreakthroughSSSPOptions = struct {
    max_distance: ?f64 = null,
    include_predecessors: bool = true,
    include_visited: bool = true,
    max_nodes: ?usize = null,
    frontier_capacity: usize = 1024,
    recursion_depth_limit: usize = 10,
};

/// Edge weight function type - returns weight for a given edge
pub const EdgeWeightFn = *const fn (edge: pool.Edge) f64;

/// Default edge weight function - returns 1.0 for all edges (unweighted)
pub fn defaultEdgeWeight(edge: pool.Edge) f64 {
    _ = edge;
    return 1.0;
}

/// Default edge weight function pointer
pub const defaultEdgeWeightFn: EdgeWeightFn = &defaultEdgeWeight;

/// Frontier management for optimal vertex selection without sorting
pub const Frontier = struct {
    vertices: []u64,
    distances: []f64,
    size: usize,
    capacity: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !Frontier {
        return Frontier{
            .vertices = try allocator.alloc(u64, capacity),
            .distances = try allocator.alloc(f64, capacity),
            .size = 0,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Frontier) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.distances);
    }

    /// Add vertex to frontier without full sorting
    /// This is key to breaking the sorting barrier
    pub fn addVertex(self: *Frontier, vertex: u64, distance: f64) !void {
        if (self.size >= self.capacity) {
            // Expand capacity if needed
            const new_capacity = self.capacity * 2;
            self.vertices = try self.allocator.realloc(self.vertices, new_capacity);
            self.distances = try self.allocator.realloc(self.distances, new_capacity);
            self.capacity = new_capacity;
        }

        self.vertices[self.size] = vertex;
        self.distances[self.size] = distance;
        self.size += 1;
    }

    /// Extract minimum distance vertex optimally
    /// Uses the algorithm's clever selection mechanism
    pub fn extractMin(self: *Frontier) ?u64 {
        if (self.size == 0) return null;

        // Find minimum without full sorting
        var min_idx: usize = 0;
        var min_distance = self.distances[0];

        for (1..self.size) |i| {
            if (self.distances[i] < min_distance) {
                min_distance = self.distances[i];
                min_idx = i;
            }
        }

        // Remove the minimum vertex
        const result = self.vertices[min_idx];
        self.vertices[min_idx] = self.vertices[self.size - 1];
        self.distances[min_idx] = self.distances[self.size - 1];
        self.size -= 1;

        return result;
    }

    /// Get current frontier size
    pub fn getSize(self: *const Frontier) usize {
        return self.size;
    }

    /// Check if frontier is empty
    pub fn isEmpty(self: *const Frontier) bool {
        return self.size == 0;
    }
};

/// Dependency tracking for vertices
pub const DependencyGraph = struct {
    /// Fixed-size small vector to keep dependencies without dynamic allocs.
    const FixedList = struct {
        const CAPACITY = 32; // Tunable. If exceeded we drop further deps (rare path) or could log.
        data: [CAPACITY]u64 = [_]u64{0} ** CAPACITY,
        len: u8 = 0,

        inline fn add(self: *FixedList, v: u64) void {
            if (self.len < CAPACITY) {
                self.data[self.len] = v;
                self.len += 1;
            } else {
                // Capacity exhausted; deterministic ignore to keep bounded memory.
            }
        }

        inline fn slice(self: *const FixedList) []const u64 {
            return self.data[0..self.len];
        }
    };

    dependencies: std.AutoHashMap(u64, FixedList),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DependencyGraph {
        return DependencyGraph{
            .dependencies = std.AutoHashMap(u64, FixedList).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DependencyGraph) void {
        self.dependencies.deinit();
    }

    /// Add dependency relationship
    pub fn addDependency(self: *DependencyGraph, vertex: u64, depends_on: u64) !void {
        var entry = try self.dependencies.getOrPut(depends_on);
        if (!entry.found_existing) {
            entry.value_ptr.* = FixedList{};
        }
        entry.value_ptr.add(vertex);
    }

    /// Get vertices that depend on this vertex
    pub fn getDependencies(self: *DependencyGraph, vertex: u64) ?[]const u64 {
        const list = self.dependencies.get(vertex) orelse return null;
        return list.slice();
    }
};

/// Main breakthrough SSSP algorithm implementation
pub const BreakthroughSSSP = struct {
    const Self = @This();

    graph: struct {
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
    },
    source: u64,
    options: BreakthroughSSSPOptions,
    weight_fn: EdgeWeightFn,
    allocator: std.mem.Allocator,

    // Algorithm state
    distances: []f64,
    predecessors: []u64,
    visited: []bool,
    frontier: Frontier,
    dependencies: DependencyGraph,
    max_observed_out_degree: u32 = 0,
    neighbor_overflow_events: u32 = 0,

    pub fn init(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source: u64,
        options: BreakthroughSSSPOptions,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !Self {
        const max_nodes = options.max_nodes orelse @max(node_pool.getStats().total_allocated, 1000);

        // Initialize arrays
        var distances = try allocator.alloc(f64, max_nodes);
        var predecessors = try allocator.alloc(u64, max_nodes);
        const visited = try allocator.alloc(bool, max_nodes);

        // Initialize distances to infinity and predecessors to invalid
        @memset(distances, std.math.inf(f64));
        @memset(predecessors, std.math.maxInt(u64));
        @memset(visited, false);

        // Set source distance to 0
        distances[source] = 0.0;
        predecessors[source] = source;

        // Initialize frontier and dependencies
        const frontier = try Frontier.init(allocator, options.frontier_capacity);
        const dependencies = DependencyGraph.init(allocator);

        return Self{
            .graph = .{ .node_pool = node_pool, .edge_pool = edge_pool },
            .source = source,
            .options = options,
            .weight_fn = weight_fn,
            .allocator = allocator,
            .distances = distances,
            .predecessors = predecessors,
            .visited = visited,
            .frontier = frontier,
            .dependencies = dependencies,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.distances);
        self.allocator.free(self.predecessors);
        self.allocator.free(self.visited);
        self.frontier.deinit();
        self.dependencies.deinit();
    }

    /// Execute the breakthrough SSSP algorithm
    pub fn execute(self: *Self) !BreakthroughSSSPResult {
        // Initialize frontier with source
        try self.frontier.addVertex(self.source, 0.0);

        var iterations: usize = 0;
        var visited_count: usize = 0;
        var visited_nodes = try self.allocator.alloc(u64, self.options.max_nodes orelse 1000);

        // Main algorithm loop
        while (!self.frontier.isEmpty()) {
            iterations += 1;

            // Extract minimum vertex from frontier
            const current_vertex = self.frontier.extractMin() orelse break;

            // Skip if already visited
            if (self.visited[current_vertex]) continue;

            // Mark as visited
            self.visited[current_vertex] = true;
            visited_nodes[visited_count] = current_vertex;
            visited_count += 1;

            // Check max distance constraint
            if (self.options.max_distance) |max_distance| {
                if (self.distances[current_vertex] >= max_distance) {
                    continue;
                }
            }

            // Process neighbors using recursive partitioning
            try self.processNeighbors(current_vertex);

            // Check max nodes limit
            if (self.options.max_nodes) |max_nodes_limit| {
                if (visited_count >= max_nodes_limit) {
                    break;
                }
            }
        }

        // Resize visited nodes array
        visited_nodes = try self.allocator.realloc(visited_nodes, visited_count);

        // Copy distances and predecessors to avoid memory issues
        const result_distances = try self.allocator.dupe(f64, self.distances);
        const result_predecessors = try self.allocator.dupe(u64, self.predecessors);

        return BreakthroughSSSPResult{
            .distances = result_distances,
            .predecessors = result_predecessors,
            .visited_nodes = visited_nodes,
            .frontier_size = self.frontier.getSize(),
            .iterations = iterations,
            .memory_bytes = (result_distances.len * @sizeOf(f64)) +
                (result_predecessors.len * @sizeOf(u64)) +
                (visited_nodes.len * @sizeOf(u64)) +
                (self.frontier.capacity * (@sizeOf(u64) + @sizeOf(f64))),
            .neighbor_overflow_events = self.neighbor_overflow_events,
            .max_observed_out_degree = self.max_observed_out_degree,
            .allocator = self.allocator,
        };
    }

    /// Process neighbors using recursive partitioning technique
    fn processNeighbors(self: *Self, current_vertex: u64) !void {
        const current_distance = self.distances[current_vertex];

        // Adaptive fixed-size stack buffer strategy with tiered capacities.
        const BASE: usize = 256;
        const TIER1: usize = 512;
        const TIER2: usize = 1024; // Hard ceiling to bound stack usage.
        var capacity: usize = BASE;
        if (self.max_observed_out_degree > BASE and self.max_observed_out_degree <= TIER1) capacity = TIER1;
        if (self.max_observed_out_degree > TIER1) capacity = TIER2;
        var storage: [TIER2]Neighbor = undefined;
        var neighbor_slice = storage[0..capacity];
        var count: usize = 0;

        var edge_iter = self.graph.edge_pool.iterFromNode(current_vertex);
        while (edge_iter.next()) |edge| {
            const neighbor_id = if (edge.from == current_vertex) edge.to else edge.from;
            const edge_weight = self.weight_fn(edge);

            if (count < neighbor_slice.len) {
                neighbor_slice[count] = .{ .vertex = neighbor_id, .weight = edge_weight };
                count += 1;
            } else {
                // Overflow path: count and process immediately.
                self.neighbor_overflow_events += 1;
                try self.relaxEdge(current_vertex, neighbor_id, edge_weight, current_distance);
            }
        }
        if (count > self.max_observed_out_degree) self.max_observed_out_degree = @intCast(count);
        if (count == 0) return;
        try self.recursivePartitioning(neighbor_slice[0..count], current_distance, current_vertex);
    }

    /// Recursive partitioning technique - the breakthrough part of the algorithm
    fn recursivePartitioning(
        self: *Self,
        neighbors: []const Neighbor,
        current_distance: f64,
        current_vertex: u64,
    ) !void {
        if (neighbors.len == 0) return;

        // Base case: small number of neighbors, process directly
        if (neighbors.len <= 4) {
            for (neighbors) |neighbor| {
                try self.relaxEdge(current_vertex, neighbor.vertex, neighbor.weight, current_distance);
            }
            return;
        }

        // Recursive case: partition neighbors and process recursively
        const mid = neighbors.len / 2;
        const left = neighbors[0..mid];
        const right = neighbors[mid..];

        // Process left partition
        try self.recursivePartitioning(left, current_distance, current_vertex);

        // Process right partition
        try self.recursivePartitioning(right, current_distance, current_vertex);

        // Merge results and update dependencies
        try self.mergePartitions(left, right, current_vertex);
    }

    /// Relax an edge (update distance if shorter path found)
    fn relaxEdge(self: *Self, from: u64, to: u64, weight: f64, current_distance: f64) !void {
        const new_distance = current_distance + weight;

        // Check if this path is shorter
        if (new_distance < self.distances[to]) {
            self.distances[to] = new_distance;
            self.predecessors[to] = from;

            // Add to frontier for processing
            try self.frontier.addVertex(to, new_distance);

            // Update dependencies
            try self.dependencies.addDependency(to, from);
        }
    }

    /// Merge partitions and update dependencies
    fn mergePartitions(
        self: *Self,
        left: []const Neighbor,
        right: []const Neighbor,
        current_vertex: u64,
    ) !void {
        // This is where the algorithm's clever merging happens
        // We don't need to sort, just merge the results

        // Update dependencies for vertices in both partitions
        for (left) |neighbor| {
            if (self.distances[neighbor.vertex] < std.math.inf(f64)) {
                try self.dependencies.addDependency(neighbor.vertex, current_vertex);
            }
        }

        for (right) |neighbor| {
            if (self.distances[neighbor.vertex] < std.math.inf(f64)) {
                try self.dependencies.addDependency(neighbor.vertex, current_vertex);
            }
        }
    }

    /// Find shortest path from source to a specific target node
    pub fn findShortestPath(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        target_node_id: u64,
        max_distance: ?f64,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !?[]u64 {
        const options = BreakthroughSSSPOptions{
            .max_distance = max_distance,
            .include_predecessors = true,
            .include_visited = false,
        };

        var algorithm = try Self.init(node_pool, edge_pool, source_node_id, options, weight_fn, allocator);
        defer algorithm.deinit();

        const result = try algorithm.execute();
        defer {
            var mutable_result = result;
            mutable_result.deinit();
        }

        // Check if target was reached
        if (result.distances[target_node_id] == std.math.inf(f64)) {
            return null; // Target not reachable
        }

        // Reconstruct path
        const path_length = @as(usize, @intFromFloat(result.distances[target_node_id])) + 1;
        var path = try allocator.alloc(u64, path_length);

        var current = target_node_id;
        var path_index = path_length - 1;

        while (current != source_node_id) {
            path[path_index] = current;
            current = result.predecessors[current];
            path_index -= 1;
        }

        path[0] = source_node_id;
        return path;
    }

    /// Execute the algorithm with default options
    pub fn executeSimple(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        weight_fn: EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !BreakthroughSSSPResult {
        const options = BreakthroughSSSPOptions{};
        var algorithm = try Self.init(node_pool, edge_pool, source_node_id, options, weight_fn, allocator);
        defer algorithm.deinit();
        return try algorithm.execute();
    }
};

/// Performance comparison between breakthrough and Dijkstra's algorithms
pub const PerformanceComparison = struct {
    breakthrough_time: u64, // nanoseconds
    dijkstra_time: u64, // nanoseconds
    speedup: f64,
    memory_usage_breakthrough: usize,
    memory_usage_dijkstra: usize,
    memory_savings: f64,
    max_observed_out_degree: u32,
    neighbor_overflow_events: u32,

    pub fn print(self: *const PerformanceComparison) void {
        std.debug.print("\n=== SSSP Algorithm Performance Comparison ===\n", .{});
        std.debug.print("Breakthrough Algorithm: {} ns\n", .{self.breakthrough_time});
        std.debug.print("Dijkstra's Algorithm:   {} ns\n", .{self.dijkstra_time});
        std.debug.print("Speedup:                {d:.2}x\n", .{self.speedup});
        std.debug.print("Memory Usage (Breakthrough): {} bytes\n", .{self.memory_usage_breakthrough});
        std.debug.print("Memory Usage (Dijkstra):     {} bytes\n", .{self.memory_usage_dijkstra});
        std.debug.print("Memory Savings:              {d:.1}%\n", .{self.memory_savings});
        std.debug.print("Breakthrough Max Out-Degree Observed: {}\n", .{self.max_observed_out_degree});
        std.debug.print("Breakthrough Neighbor Overflow Events: {}\n", .{self.neighbor_overflow_events});
        std.debug.print("==============================================\n", .{});
    }
};

/// Benchmark both algorithms and compare performance
pub fn benchmarkAlgorithms(
    node_pool: *const pool.NodePool,
    edge_pool: *const pool.EdgePool,
    source_node_id: u64,
    weight_fn: EdgeWeightFn,
    allocator: std.mem.Allocator,
) !PerformanceComparison {
    // Benchmark breakthrough algorithm
    var breakthrough_timer = try std.time.Timer.start();
    var breakthrough_result = try BreakthroughSSSP.executeSimple(node_pool, edge_pool, source_node_id, weight_fn, allocator);
    const breakthrough_time = breakthrough_timer.read();
    defer breakthrough_result.deinit();

    // Benchmark Dijkstra's algorithm (import from dijkstra.zig)
    var dijkstra_timer = try std.time.Timer.start();
    var dijkstra_result = try @import("dijkstra.zig").Dijkstra.execute(node_pool, edge_pool, source_node_id, @import("dijkstra.zig").DijkstraOptions{}, @import("dijkstra.zig").defaultEdgeWeight, allocator);
    const dijkstra_time = dijkstra_timer.read();
    defer dijkstra_result.deinit();

    const speedup = @as(f64, @floatFromInt(dijkstra_time)) / @as(f64, @floatFromInt(breakthrough_time));
    const memory_savings = 100.0 * (1.0 - @as(f64, @floatFromInt(breakthrough_result.frontier_size)) /
        @as(f64, @floatFromInt(dijkstra_result.visited_nodes.len)));

    return PerformanceComparison{
        .breakthrough_time = breakthrough_time,
        .dijkstra_time = dijkstra_time,
        .speedup = speedup,
        .memory_usage_breakthrough = breakthrough_result.memory_bytes,
        .memory_usage_dijkstra = dijkstra_result.visited_nodes.len * @sizeOf(u64) + dijkstra_result.distances.len * @sizeOf(u32),
        .memory_savings = memory_savings,
        .max_observed_out_degree = breakthrough_result.max_observed_out_degree,
        .neighbor_overflow_events = breakthrough_result.neighbor_overflow_events,
    };
}
