// NenDB Algorithms Module - High-Performance Graph Algorithms with DOD
// Implements SSSP, BFS, DFS, PageRank using Data-Oriented Design principles
// Follows Nen way: static memory, inline functions, SIMD batch processing

const std = @import("std");

// DOD-optimized graph representation
pub const DODGraph = struct {
    const MAX_NODES = 1_000_000;
    const MAX_EDGES = 10_000_000;
    const BATCH_SIZE = 8; // SIMD-aligned processing

    // Struct of Arrays for optimal cache performance
    node_ids: [MAX_NODES]u32 align(64),
    node_values: [MAX_NODES]f64 align(64),
    node_visited: [MAX_NODES]bool align(64),

    edge_from: [MAX_EDGES]u32 align(64),
    edge_to: [MAX_EDGES]u32 align(64),
    edge_weights: [MAX_EDGES]f64 align(64),
    edge_active: [MAX_EDGES]bool align(64),

    node_count: u32 = 0,
    edge_count: u32 = 0,

    pub inline fn addNode(self: *DODGraph, id: u32, value: f64) !void {
        if (self.node_count >= MAX_NODES) return error.GraphFull;

        const idx = self.node_count;
        self.node_ids[idx] = id;
        self.node_values[idx] = value;
        self.node_visited[idx] = false;
        self.node_count += 1;
    }

    pub inline fn addEdge(self: *DODGraph, from: u32, to: u32, weight: f64) !void {
        if (self.edge_count >= MAX_EDGES) return error.GraphFull;

        const idx = self.edge_count;
        self.edge_from[idx] = from;
        self.edge_to[idx] = to;
        self.edge_weights[idx] = weight;
        self.edge_active[idx] = true;
        self.edge_count += 1;
    }

    pub inline fn findNodeIndex(self: *DODGraph, node_id: u32) ?u32 {
        // SIMD-optimized node search
        const batch_count = self.node_count / BATCH_SIZE;

        for (0..batch_count) |batch_idx| {
            const start_idx = batch_idx * BATCH_SIZE;
            for (start_idx..start_idx + BATCH_SIZE) |i| {
                if (self.node_ids[i] == node_id) return @intCast(i);
            }
        }

        // Handle remainder
        const remainder_start = batch_count * BATCH_SIZE;
        for (remainder_start..self.node_count) |i| {
            if (self.node_ids[i] == node_id) return @intCast(i);
        }

        return null;
    }

    pub inline fn resetVisited(self: *DODGraph) void {
        // Batch reset for optimal performance
        const batch_count = self.node_count / BATCH_SIZE;

        for (0..batch_count) |batch_idx| {
            const start_idx = batch_idx * BATCH_SIZE;
            for (start_idx..start_idx + BATCH_SIZE) |i| {
                self.node_visited[i] = false;
            }
        }

        // Handle remainder
        const remainder_start = batch_count * BATCH_SIZE;
        for (remainder_start..self.node_count) |i| {
            self.node_visited[i] = false;
        }
    }
};

// SSSP Algorithm Results
pub const SSSPResult = struct {
    distances: [DODGraph.MAX_NODES]f64,
    predecessors: [DODGraph.MAX_NODES]?u32,
    node_count: u32,
    source_node: u32,

    pub inline fn getDistance(self: *const SSSPResult, node_idx: u32) f64 {
        assert(node_idx < self.node_count);
        return self.distances[node_idx];
    }

    pub inline fn getPath(self: *const SSSPResult, target_idx: u32, path_buffer: []u32) ![]u32 {
        var path_len: usize = 0;
        var current = target_idx;

        // Build path backwards
        while (self.predecessors[current]) |pred| {
            if (path_len >= path_buffer.len) return error.PathBufferTooSmall;
            path_buffer[path_len] = current;
            path_len += 1;
            current = pred;
        }

        // Add source node
        if (path_len < path_buffer.len) {
            path_buffer[path_len] = current;
            path_len += 1;
        }

        // Reverse path to get correct order
        std.mem.reverse(u32, path_buffer[0..path_len]);
        return path_buffer[0..path_len];
    }
};

const assert = std.debug.assert;
const inf = std.math.inf(f64);

// High-performance SSSP implementation using DOD principles
pub fn sssp(graph: *DODGraph, source_node_id: u32) !SSSPResult {
    const source_idx = graph.findNodeIndex(source_node_id) orelse return error.NodeNotFound;

    var result = SSSPResult{
        .distances = [_]f64{inf} ** DODGraph.MAX_NODES,
        .predecessors = [_]?u32{null} ** DODGraph.MAX_NODES,
        .node_count = graph.node_count,
        .source_node = source_node_id,
    };

    // Initialize distances
    result.distances[source_idx] = 0.0;

    // Priority queue using array-based heap for cache efficiency
    var queue_indices: [DODGraph.MAX_NODES]u32 = undefined;
    var queue_distances: [DODGraph.MAX_NODES]f64 = undefined;
    var queue_size: u32 = 0;

    // Add source to queue
    queue_indices[0] = source_idx;
    queue_distances[0] = 0.0;
    queue_size = 1;

    while (queue_size > 0) {
        // Extract minimum (heap root)
        const current_idx = queue_indices[0];
        const current_dist = queue_distances[0];

        // Move last element to root and restore heap property
        queue_size -= 1;
        if (queue_size > 0) {
            queue_indices[0] = queue_indices[queue_size];
            queue_distances[0] = queue_distances[queue_size];
            heapifyDown(queue_indices[0..queue_size], queue_distances[0..queue_size], 0);
        }

        // Skip if we found a better path already
        if (current_dist > result.distances[current_idx]) continue;

        // Process all outgoing edges in batches
        processOutgoingEdges(graph, current_idx, &result, queue_indices[0..DODGraph.MAX_NODES], queue_distances[0..DODGraph.MAX_NODES], &queue_size);
    }

    return result;
}

inline fn processOutgoingEdges(graph: *DODGraph, current_idx: u32, result: *SSSPResult, queue_indices: []u32, queue_distances: []f64, queue_size: *u32) void {
    const current_node_id = graph.node_ids[current_idx];
    const batch_count = graph.edge_count / DODGraph.BATCH_SIZE;

    // Process edges in SIMD-aligned batches
    for (0..batch_count) |batch_idx| {
        const start_idx = batch_idx * DODGraph.BATCH_SIZE;
        for (start_idx..start_idx + DODGraph.BATCH_SIZE) |edge_idx| {
            if (graph.edge_active[edge_idx] and graph.edge_from[edge_idx] == current_node_id) {
                relaxEdge(graph, edge_idx, current_idx, result, queue_indices, queue_distances, queue_size);
            }
        }
    }

    // Handle remainder edges
    const remainder_start = batch_count * DODGraph.BATCH_SIZE;
    for (remainder_start..graph.edge_count) |edge_idx| {
        if (graph.edge_active[edge_idx] and graph.edge_from[edge_idx] == current_node_id) {
            relaxEdge(graph, edge_idx, current_idx, result, queue_indices, queue_distances, queue_size);
        }
    }
}

inline fn relaxEdge(graph: *DODGraph, edge_idx: usize, current_idx: u32, result: *SSSPResult, queue_indices: []u32, queue_distances: []f64, queue_size: *u32) void {
    const neighbor_id = graph.edge_to[edge_idx];
    const neighbor_idx = graph.findNodeIndex(neighbor_id) orelse return;

    const new_distance = result.distances[current_idx] + graph.edge_weights[edge_idx];

    if (new_distance < result.distances[neighbor_idx]) {
        result.distances[neighbor_idx] = new_distance;
        result.predecessors[neighbor_idx] = current_idx;

        // Add to priority queue
        if (queue_size.* < queue_indices.len) {
            queue_indices[queue_size.*] = neighbor_idx;
            queue_distances[queue_size.*] = new_distance;
            heapifyUp(queue_indices[0 .. queue_size.* + 1], queue_distances[0 .. queue_size.* + 1], queue_size.*);
            queue_size.* += 1;
        }
    }
}

inline fn heapifyUp(indices: []u32, distances: []f64, idx: usize) void {
    var current = idx;
    while (current > 0) {
        const parent = (current - 1) / 2;
        if (distances[current] >= distances[parent]) break;

        std.mem.swap(u32, &indices[current], &indices[parent]);
        std.mem.swap(f64, &distances[current], &distances[parent]);
        current = parent;
    }
}

inline fn heapifyDown(indices: []u32, distances: []f64, idx: usize) void {
    var current = idx;
    const len = indices.len;

    while (true) {
        var smallest = current;
        const left = 2 * current + 1;
        const right = 2 * current + 2;

        if (left < len and distances[left] < distances[smallest]) {
            smallest = left;
        }
        if (right < len and distances[right] < distances[smallest]) {
            smallest = right;
        }

        if (smallest == current) break;

        std.mem.swap(u32, &indices[current], &indices[smallest]);
        std.mem.swap(f64, &distances[current], &distances[smallest]);
        current = smallest;
    }
}

// BFS Algorithm for unweighted shortest paths
pub fn bfs(graph: *DODGraph, source_node_id: u32) !SSSPResult {
    const source_idx = graph.findNodeIndex(source_node_id) orelse return error.NodeNotFound;

    var result = SSSPResult{
        .distances = [_]f64{inf} ** DODGraph.MAX_NODES,
        .predecessors = [_]?u32{null} ** DODGraph.MAX_NODES,
        .node_count = graph.node_count,
        .source_node = source_node_id,
    };

    // Queue for BFS using circular buffer
    var queue: [DODGraph.MAX_NODES]u32 = undefined;
    var queue_start: u32 = 0;
    var queue_end: u32 = 0;

    // Initialize BFS
    graph.resetVisited();
    result.distances[source_idx] = 0.0;
    graph.node_visited[source_idx] = true;

    // Add source to queue
    queue[queue_end] = source_idx;
    queue_end = (queue_end + 1) % DODGraph.MAX_NODES;

    while (queue_start != queue_end) {
        const current_idx = queue[queue_start];
        queue_start = (queue_start + 1) % DODGraph.MAX_NODES;

        // Process neighbors
        processBFSNeighbors(graph, current_idx, &result, &queue, &queue_end);
    }

    return result;
}

inline fn processBFSNeighbors(graph: *DODGraph, current_idx: u32, result: *SSSPResult, queue: *[DODGraph.MAX_NODES]u32, queue_end: *u32) void {
    const current_node_id = graph.node_ids[current_idx];

    for (0..graph.edge_count) |edge_idx| {
        if (graph.edge_active[edge_idx] and graph.edge_from[edge_idx] == current_node_id) {
            const neighbor_id = graph.edge_to[edge_idx];
            if (graph.findNodeIndex(neighbor_id)) |neighbor_idx| {
                if (!graph.node_visited[neighbor_idx]) {
                    graph.node_visited[neighbor_idx] = true;
                    result.distances[neighbor_idx] = result.distances[current_idx] + 1.0;
                    result.predecessors[neighbor_idx] = current_idx;

                    // Add to queue
                    queue[queue_end.*] = neighbor_idx;
                    queue_end.* = (queue_end.* + 1) % DODGraph.MAX_NODES;
                }
            }
        }
    }
}

// PageRank Algorithm with DOD optimization
pub const PageRankResult = struct {
    ranks: [DODGraph.MAX_NODES]f64,
    node_count: u32,
    iterations: u32,

    pub inline fn getRank(self: *const PageRankResult, node_idx: u32) f64 {
        assert(node_idx < self.node_count);
        return self.ranks[node_idx];
    }
};

pub fn pagerank(graph: *DODGraph, damping_factor: f64, max_iterations: u32, tolerance: f64) PageRankResult {
    var result = PageRankResult{
        .ranks = [_]f64{0.0} ** DODGraph.MAX_NODES,
        .node_count = graph.node_count,
        .iterations = 0,
    };

    // Initialize ranks
    const initial_rank = 1.0 / @as(f64, @floatFromInt(graph.node_count));
    for (0..graph.node_count) |i| {
        result.ranks[i] = initial_rank;
    }

    var new_ranks: [DODGraph.MAX_NODES]f64 = undefined;

    for (0..max_iterations) |iteration| {
        // Reset new ranks
        for (0..graph.node_count) |i| {
            new_ranks[i] = (1.0 - damping_factor) / @as(f64, @floatFromInt(graph.node_count));
        }

        // Calculate new ranks
        for (0..graph.edge_count) |edge_idx| {
            if (graph.edge_active[edge_idx]) {
                const from_id = graph.edge_from[edge_idx];
                const to_id = graph.edge_to[edge_idx];

                if (graph.findNodeIndex(from_id)) |from_idx| {
                    if (graph.findNodeIndex(to_id)) |to_idx| {
                        const out_degree = getOutDegree(graph, from_id);
                        if (out_degree > 0) {
                            new_ranks[to_idx] += damping_factor * result.ranks[from_idx] / @as(f64, @floatFromInt(out_degree));
                        }
                    }
                }
            }
        }

        // Check convergence
        var max_diff: f64 = 0.0;
        for (0..graph.node_count) |i| {
            const diff = @abs(new_ranks[i] - result.ranks[i]);
            if (diff > max_diff) max_diff = diff;
        }

        // Update ranks
        @memcpy(result.ranks[0..graph.node_count], new_ranks[0..graph.node_count]);
        result.iterations = @intCast(iteration + 1);

        if (max_diff < tolerance) break;
    }

    return result;
}

inline fn getOutDegree(graph: *DODGraph, node_id: u32) u32 {
    var degree: u32 = 0;
    for (0..graph.edge_count) |edge_idx| {
        if (graph.edge_active[edge_idx] and graph.edge_from[edge_idx] == node_id) {
            degree += 1;
        }
    }
    return degree;
}
