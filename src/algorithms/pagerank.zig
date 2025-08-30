// NenDB PageRank Algorithm
// Optimized for static memory pools and efficient graph centrality analysis

const std = @import("std");
const nendb = @import("nendb");
const pool = nendb.memory;

pub const PageRankResult = struct {
    scores: []f64,
    iterations: u32,
    converged: bool,
    final_error: f64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *PageRankResult) void {
        self.allocator.free(self.scores);
    }
};

pub const PageRankOptions = struct {
    damping_factor: f64 = 0.85,        // Standard PageRank damping factor
    max_iterations: u32 = 100,          // Maximum iterations before giving up
    convergence_threshold: f64 = 1e-6,  // Convergence threshold
    initial_score: f64 = 1.0,           // Initial PageRank score for all nodes
    personalization: ?[]f64 = null,     // Personalization vector (teleportation)
    teleport_nodes: ?[]u32 = null,      // Specific nodes to teleport to
};

/// PageRank algorithm for graph centrality analysis
/// Uses our static memory pool structure for efficient memory access
pub const PageRank = struct {
    const Self = @This();

    /// Execute PageRank algorithm on the graph
    /// Returns PageRankResult with centrality scores
    pub fn execute(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        options: PageRankOptions,
        allocator: std.mem.Allocator,
    ) !PageRankResult {
        const total_nodes = node_pool.getStats().total_allocated;
        if (total_nodes == 0) {
            return PageRankResult{
                .scores = &[_]f64{},
                .iterations = 0,
                .converged = true,
                .final_error = 0.0,
                .allocator = allocator,
            };
        }

        // Initialize PageRank scores
        var current_scores = try allocator.alloc(f64, total_nodes);
        var new_scores = try allocator.alloc(f64, total_nodes);
        defer allocator.free(new_scores);

        // Initialize all nodes with equal scores
        @memset(current_scores, options.initial_score / @as(f64, @floatFromInt(total_nodes)));

        // Apply personalization if provided
        if (options.personalization) |personalization| {
            if (personalization.len == total_nodes) {
                @memcpy(current_scores, personalization);
            }
        }

        // Calculate out-degrees for each node
        var out_degrees = try allocator.alloc(u32, total_nodes);
        defer allocator.free(out_degrees);
        @memset(out_degrees, 0);

        // Count out-edges for each node
        var edge_iter = edge_pool.iterator();
        while (edge_iter.next()) |edge| {
            out_degrees[edge.from] += 1;
        }

        // Main PageRank iteration loop
        var iteration: u32 = 0;
        var converged = false;
        var final_error: f64 = 0.0;

        while (iteration < options.max_iterations and !converged) {
            // Reset new scores
            @memset(new_scores, 0.0);

            // Calculate new PageRank scores
            for (0..total_nodes) |node_id| {
                var score_contribution: f64 = 0.0;

                // Get incoming edges to this node
                var incoming_iter = edge_pool.iterToNode(@intCast(node_id));
                while (incoming_iter.next()) |edge| {
                    const source_id = edge.from;
                    if (out_degrees[source_id] > 0) {
                        score_contribution += current_scores[source_id] / @as(f64, @floatFromInt(out_degrees[source_id]));
                    }
                }

                // Apply PageRank formula: PR(v) = (1-d)/N + d * sum(PR(u)/out_degree(u))
                new_scores[node_id] = (1.0 - options.damping_factor) / @as(f64, @floatFromInt(total_nodes)) +
                                     options.damping_factor * score_contribution;
            }

            // Apply teleportation to specific nodes if provided
            if (options.teleport_nodes) |teleport_nodes| {
                const teleport_score = (1.0 - options.damping_factor) / @as(f64, @floatFromInt(teleport_nodes.len));
                for (teleport_nodes) |teleport_node_id| {
                    if (teleport_node_id < total_nodes) {
                        new_scores[teleport_node_id] += teleport_score;
                    }
                }
            }

            // Check convergence
            final_error = 0.0;
            for (0..total_nodes) |node_id| {
                const diff = @abs(new_scores[node_id] - current_scores[node_id]);
                if (diff > final_error) {
                    final_error = diff;
                }
            }

            converged = final_error < options.convergence_threshold;

            // Swap arrays for next iteration
            const temp = current_scores;
            current_scores = new_scores;
            new_scores = temp;

            iteration += 1;
        }

        return PageRankResult{
            .scores = current_scores,
            .iterations = iteration,
            .converged = converged,
            .final_error = final_error,
            .allocator = allocator,
        };
    }

    /// Execute PageRank with a specific source node (Personalized PageRank)
    /// Returns PageRankResult with personalized centrality scores
    pub fn executePersonalized(
        node_pool: *const pool.NodePool,
        edge_pool: *const pool.EdgePool,
        source_node_id: u32,
        options: PageRankOptions,
        allocator: std.mem.Allocator,
    ) !PageRankResult {
        const total_nodes = node_pool.getStats().total_allocated;
        if (source_node_id >= total_nodes) {
            return error.InvalidSourceNode;
        }

        // Create personalization vector with teleportation to source node
        var personalization = try allocator.alloc(f64, total_nodes);
        defer allocator.free(personalization);
        @memset(personalization, 0.0);
        personalization[source_node_id] = 1.0;

        const personalized_options = PageRankOptions{
            .damping_factor = options.damping_factor,
            .max_iterations = options.max_iterations,
            .convergence_threshold = options.convergence_threshold,
            .initial_score = options.initial_score,
            .personalization = personalization,
            .teleport_nodes = null,
        };

        return execute(node_pool, edge_pool, personalized_options, allocator);
    }

    /// Get top-k nodes by PageRank score
    /// Returns array of node IDs sorted by descending PageRank score
    pub fn getTopNodes(
        result: *const PageRankResult,
        k: usize,
        allocator: std.mem.Allocator,
    ) ![]u32 {
        const total_nodes = result.scores.len;
        const top_k = @min(k, total_nodes);

        const NodeScore = struct {
            node_id: u64,
            score: f64,
        };

        // Create array of (node_id, score) pairs
        var node_scores = try allocator.alloc(NodeScore, total_nodes);
        defer allocator.free(node_scores);

        for (0..total_nodes) |node_id| {
            node_scores[node_id] = .{ .node_id = @intCast(node_id), .score = result.scores[node_id] };
        }

        // Sort by ascending score
        std.mem.sort(NodeScore, node_scores, {}, struct {
            fn lessThan(_: void, a: NodeScore, b: NodeScore) bool {
                return a.score < b.score;
            }
        }.lessThan);

        // Extract top-k node IDs (reverse to get descending order)
        var top_nodes = try allocator.alloc(u32, top_k);
        for (0..top_k) |i| {
            top_nodes[i] = @intCast(node_scores[total_nodes - 1 - i].node_id);
        }

        return top_nodes;
    }

    /// Get PageRank score for a specific node
    /// Returns the PageRank score or null if node doesn't exist
    pub fn getScore(result: *const PageRankResult, node_id: u32) ?f64 {
        if (node_id < result.scores.len) {
            return result.scores[node_id];
        }
        return null;
    }

    /// Normalize PageRank scores to sum to 1.0
    /// Modifies the scores in-place
    pub fn normalizeScores(result: *PageRankResult) void {
        var sum: f64 = 0.0;
        for (result.scores) |score| {
            sum += score;
        }

        if (sum > 0.0) {
            for (0..result.scores.len) |i| {
                result.scores[i] /= sum;
            }
        }
    }

    /// Calculate PageRank statistics
    /// Returns statistics about the PageRank distribution
    pub fn getStatistics(result: *const PageRankResult) struct {
        min_score: f64,
        max_score: f64,
        mean_score: f64,
        median_score: f64,
        std_deviation: f64,
    } {
        if (result.scores.len == 0) {
            return .{
                .min_score = 0.0,
                .max_score = 0.0,
                .mean_score = 0.0,
                .median_score = 0.0,
                .std_deviation = 0.0,
            };
        }

        // Calculate min, max, and mean
        var min_score = result.scores[0];
        var max_score = result.scores[0];
        var sum: f64 = 0.0;

        for (result.scores) |score| {
            if (score < min_score) min_score = score;
            if (score > max_score) max_score = score;
            sum += score;
        }

        const mean_score = sum / @as(f64, @floatFromInt(result.scores.len));

        // Calculate standard deviation
        var variance_sum: f64 = 0.0;
        for (result.scores) |score| {
            const diff = score - mean_score;
            variance_sum += diff * diff;
        }
        const std_deviation = @sqrt(variance_sum / @as(f64, @floatFromInt(result.scores.len)));

        // Calculate median
        const sorted_scores = std.mem.dupe(std.testing.allocator, f64, result.scores) catch unreachable;
        defer std.testing.allocator.free(sorted_scores);
        std.mem.sort(f64, sorted_scores, {}, std.math.order);
        
        const median_score = if (sorted_scores.len % 2 == 0)
            (sorted_scores[sorted_scores.len / 2 - 1] + sorted_scores[sorted_scores.len / 2]) / 2.0
        else
            sorted_scores[sorted_scores.len / 2];

        return .{
            .min_score = min_score,
            .max_score = max_score,
            .mean_score = mean_score,
            .median_score = median_score,
            .std_deviation = std_deviation,
        };
    }
};

test "PageRank algorithm basic functionality" {
    const allocator = std.testing.allocator;
    
    // Create a simple graph: A -> B -> C -> A (cycle)
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    
    // Add nodes
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    
    // Add edges forming a cycle
    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 1, .to = 2, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 2, .to = 0, .type = 0, .properties = &[_]u8{} });
    
    // Test PageRank
    const result = try PageRank.execute(&node_pool, &edge_pool, .{}, allocator);
    defer result.deinit();
    
    // Should converge in reasonable number of iterations
    try std.testing.expect(result.converged);
    try std.testing.expect(result.iterations > 0);
    try std.testing.expect(result.iterations <= 100);
    
    // All nodes should have similar scores in a cycle
    try std.testing.expect(result.scores.len == 3);
    try std.testing.expect(@abs(result.scores[0] - result.scores[1]) < 0.1);
    try std.testing.expect(@abs(result.scores[1] - result.scores[2]) < 0.1);
}

test "PageRank personalized execution" {
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
    
    // Test personalized PageRank from node A
    const result = try PageRank.executePersonalized(&node_pool, &edge_pool, 0, .{}, allocator);
    defer result.deinit();
    
    try std.testing.expect(result.converged);
    try std.testing.expect(result.scores.len == 4);
    
    // Node A should have higher score due to personalization
    try std.testing.expect(result.scores[0] > result.scores[1]);
    try std.testing.expect(result.scores[0] > result.scores[2]);
    try std.testing.expect(result.scores[0] > result.scores[3]);
}

test "PageRank top nodes and statistics" {
    const allocator = std.testing.allocator;
    
    var node_pool = pool.NodePool.init();
    var edge_pool = pool.EdgePool.init();
    
    // Create a simple graph
    _ = try node_pool.alloc(.{ .id = 0, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 1, .labels = &[_]u32{}, .properties = &[_]u8{} });
    _ = try node_pool.alloc(.{ .id = 2, .labels = &[_]u32{}, .properties = &[_]u8{} });
    
    _ = try edge_pool.alloc(.{ .from = 0, .to = 1, .type = 0, .properties = &[_]u8{} });
    _ = try edge_pool.alloc(.{ .from = 1, .to = 2, .type = 0, .properties = &[_]u8{} });
    
    const result = try PageRank.execute(&node_pool, &edge_pool, .{}, allocator);
    defer result.deinit();
    
    // Get top 2 nodes
    const top_nodes = try PageRank.getTopNodes(&result, 2, allocator);
    defer allocator.free(top_nodes);
    
    try std.testing.expectEqual(@as(usize, 2), top_nodes.len);
    
    // Get statistics
    const stats = PageRank.getStatistics(&result);
    try std.testing.expect(stats.min_score >= 0.0);
    try std.testing.expect(stats.max_score >= stats.min_score);
    try std.testing.expect(stats.mean_score >= stats.min_score);
    try std.testing.expect(stats.mean_score <= stats.max_score);
}
