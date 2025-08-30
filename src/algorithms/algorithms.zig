// NenDB Algorithms Module
// Unified interface for all graph algorithms

const std = @import("std");
const nendb = @import("nendb");
const pool = nendb.memory;

// Import all algorithms
pub const bfs = @import("bfs.zig");
pub const dijkstra = @import("dijkstra.zig");
pub const pagerank = @import("pagerank.zig");

/// Algorithm types supported by NenDB
pub const AlgorithmType = enum {
    bfs,           // Breadth-First Search
    dijkstra,      // Dijkstra's Shortest Path
    pagerank,      // PageRank centrality
};

/// Algorithm execution options
pub const AlgorithmOptions = union(AlgorithmType) {
    bfs: bfs.BFSOptions,
    dijkstra: dijkstra.DijkstraOptions,
    pagerank: pagerank.PageRankOptions,
};

/// Algorithm result types
pub const AlgorithmResult = union(AlgorithmType) {
    bfs: bfs.BFSResult,
    dijkstra: dijkstra.DijkstraResult,
    pagerank: pagerank.PageRankResult,
};

/// Algorithm executor that can run any supported algorithm
pub const AlgorithmExecutor = struct {
    const Self = @This();

    /// Execute an algorithm with the given options
    pub fn execute(
        algorithm: AlgorithmType,
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: ?u32,
        options: AlgorithmOptions,
        allocator: std.mem.Allocator,
    ) !AlgorithmResult {
        return switch (algorithm) {
            .bfs => {
                const bfs_options = switch (options) {
                    .bfs => |opts| opts,
                    else => bfs.BFSOptions{},
                };
                const result = try bfs.BFS.execute(node_pool, edge_pool, source_node_id orelse 0, bfs_options, allocator);
                return AlgorithmResult{ .bfs = result };
            },
            .dijkstra => {
                const dijkstra_options = switch (options) {
                    .dijkstra => |opts| opts,
                    else => dijkstra.DijkstraOptions{},
                };
                const weight_fn = dijkstra.defaultEdgeWeight;
                const result = try dijkstra.Dijkstra.execute(node_pool, edge_pool, source_node_id orelse 0, dijkstra_options, weight_fn, allocator);
                return AlgorithmResult{ .dijkstra = result };
            },
            .pagerank => {
                const pagerank_options = switch (options) {
                    .pagerank => |opts| opts,
                    else => pagerank.PageRankOptions{},
                };
                const result = try pagerank.PageRank.execute(node_pool, edge_pool, pagerank_options, allocator);
                return AlgorithmResult{ .pagerank = result };
            },
        };
    }

    /// Execute an algorithm with default options
    pub fn executeDefault(
        algorithm: AlgorithmType,
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: ?u32,
        allocator: std.mem.Allocator,
    ) !AlgorithmResult {
        const default_options = switch (algorithm) {
            .bfs => AlgorithmOptions{ .bfs = .{} },
            .dijkstra => AlgorithmOptions{ .dijkstra = .{} },
            .pagerank => AlgorithmOptions{ .pagerank = .{} },
        };
        return execute(algorithm, node_pool, edge_pool, source_node_id, default_options, allocator);
    }

    /// Execute personalized PageRank from a specific source node
    pub fn executePersonalizedPageRank(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u32,
        options: pagerank.PageRankOptions,
        allocator: std.mem.Allocator,
    ) !AlgorithmResult {
        const result = try pagerank.PageRank.executePersonalized(node_pool, edge_pool, source_node_id, options, allocator);
        return AlgorithmResult{ .pagerank = result };
    }

    /// Execute Dijkstra with custom weight function
    pub fn executeDijkstraWithWeights(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u32,
        options: dijkstra.DijkstraOptions,
        weight_fn: dijkstra.EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !AlgorithmResult {
        const result = try dijkstra.Dijkstra.execute(node_pool, edge_pool, source_node_id, options, weight_fn, allocator);
        return AlgorithmResult{ .dijkstra = result };
    }

    /// Find shortest path using Dijkstra's algorithm
    pub fn findShortestPath(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u64,
        target_node_id: u64,
        max_distance: ?u32,
        weight_fn: dijkstra.EdgeWeightFn,
        allocator: std.mem.Allocator,
    ) !?[]u64 {
        return dijkstra.Dijkstra.findShortestPath(node_pool, edge_pool, source_node_id, target_node_id, max_distance, weight_fn, allocator);
    }

    /// Find path using BFS
    pub fn findBFSPath(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u32,
        target_node_id: u32,
        max_depth: ?u32,
        allocator: std.mem.Allocator,
    ) !?[]u32 {
        return bfs.BFS.findPath(node_pool, edge_pool, source_node_id, target_node_id, max_depth, allocator);
    }

    /// Get top-k nodes by PageRank score
    pub fn getTopPageRankNodes(
        result: *const pagerank.PageRankResult,
        k: usize,
        allocator: std.mem.Allocator,
    ) ![]u32 {
        return pagerank.PageRank.getTopNodes(result, k, allocator);
    }

    /// Get PageRank statistics
    pub fn getPageRankStatistics(result: *const pagerank.PageRankResult) pagerank.PageRank.Statistics {
        return pagerank.PageRank.getStatistics(result);
    }

    /// Clean up algorithm result
    pub fn deinitResult(result: AlgorithmResult) void {
        switch (result) {
            .bfs => |r| {
                var mutable_r = r;
                mutable_r.deinit();
            },
            .dijkstra => |r| {
                var mutable_r = r;
                mutable_r.deinit();
            },
            .pagerank => |r| {
                var mutable_r = r;
                mutable_r.deinit();
            },
        }
    }
};

/// Utility functions for algorithm analysis
pub const AlgorithmUtils = struct {
    /// Check if a graph is connected using BFS
    pub fn isGraphConnected(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        allocator: std.mem.Allocator,
    ) !bool {
        const total_nodes = node_pool.getStats().total_allocated;
        if (total_nodes == 0) return true;

        // Start BFS from first node
        const result = try bfs.BFS.execute(node_pool, edge_pool, 0, .{}, allocator);
        defer {
            var mutable_result = result;
            mutable_result.deinit();
        }

        // Graph is connected if BFS visits all nodes
        return result.visited_nodes.len == total_nodes;
    }

    /// Get graph diameter (longest shortest path) using BFS
    pub fn getGraphDiameter(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        allocator: std.mem.Allocator,
    ) !u32 {
        const total_nodes = node_pool.getStats().total_allocated;
        if (total_nodes <= 1) return 0;

        var max_diameter: u32 = 0;

        // Check BFS from each node to find maximum distance
        for (0..total_nodes) |source_node_id| {
            const result = try bfs.BFS.execute(node_pool, edge_pool, @intCast(source_node_id), .{}, allocator);
            defer {
                var mutable_result = result;
                mutable_result.deinit();
            }

            // Find maximum distance in this BFS
            for (result.distances) |distance| {
                if (distance != std.math.maxInt(u32) and distance > max_diameter) {
                    max_diameter = distance;
                }
            }
        }

        return max_diameter;
    }

    /// Get average shortest path length using BFS
    pub fn getAverageShortestPathLength(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        allocator: std.mem.Allocator,
    ) !f64 {
        const total_nodes = node_pool.getStats().total_allocated;
        if (total_nodes <= 1) return 0.0;

        var total_path_length: u64 = 0;
        var path_count: u64 = 0;

        // Calculate shortest paths from each node
        for (0..total_nodes) |source_node_id| {
            const result = try bfs.BFS.execute(node_pool, edge_pool, @intCast(source_node_id), .{}, allocator);
            defer {
                var mutable_result = result;
                mutable_result.deinit();
            }

            // Sum up all reachable distances
            for (result.distances) |distance| {
                if (distance != std.math.maxInt(u32)) {
                    total_path_length += distance;
                    path_count += 1;
                }
            }
        }

        if (path_count == 0) return 0.0;
        return @as(f64, @floatFromInt(total_path_length)) / @as(f64, @floatFromInt(path_count));
    }

    /// Get graph density (edges / (nodes * (nodes - 1)))
    pub fn getGraphDensity(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
    ) f64 {
        const total_nodes = node_pool.getStats().total_allocated;
        const total_edges = edge_pool.getStats().total_allocated;

        if (total_nodes <= 1) return 0.0;
        const max_possible_edges = @as(f64, @floatFromInt(total_nodes * (total_nodes - 1)));
        return @as(f64, @floatFromInt(total_edges)) / max_possible_edges;
    }
};

test "algorithms module integration" {
    const allocator = std.testing.allocator;
    
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    
    // Create a simple graph: A -> B -> C
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    
    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 1, .to = 2, .type = 0, .properties = &[_]u8{} });
    
    // Test BFS execution
    const bfs_result = try AlgorithmExecutor.executeDefault(.bfs, &node_pool, &edge_pool, 0, allocator);
    defer AlgorithmExecutor.deinitResult(bfs_result);
    
    try std.testing.expect(bfs_result == .bfs);
    try std.testing.expectEqual(@as(usize, 3), bfs_result.bfs.visited_nodes.len);
    
    // Test PageRank execution
    const pagerank_result = try AlgorithmExecutor.executeDefault(.pagerank, &node_pool, &edge_pool, null, allocator);
    defer AlgorithmExecutor.deinitResult(pagerank_result);
    
    try std.testing.expect(pagerank_result == .pagerank);
    try std.testing.expect(pagerank_result.pagerank.converged);
    
    // Test utility functions
    try std.testing.expect(try AlgorithmUtils.isGraphConnected(&node_pool, &edge_pool, allocator));
    try std.testing.expectEqual(@as(u32, 2), try AlgorithmUtils.getGraphDiameter(&node_pool, &edge_pool, allocator));
    
    const density = AlgorithmUtils.getGraphDensity(&node_pool, &edge_pool);
    try std.testing.expect(density > 0.0);
    try std.testing.expect(density <= 1.0);
}
