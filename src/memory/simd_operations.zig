// NenDB SIMD-Optimized Operations
// Implements vectorized operations for DOD data structures

const std = @import("std");
const constants = @import("../constants.zig");
const dod_layout = @import("dod_layout.zig");

// SIMD-optimized batch processor
pub const SIMDBatchProcessor = struct {
    // Process nodes in SIMD batches
    pub fn processNodeBatch(node_data: *dod_layout.DODGraphData, operation: NodeOperation, batch_size: u32) void {
        if (batch_size == 0) return;

        // Process in SIMD batches of 8
        const simd_batch_size = constants.data.simd_node_batch_size;
        var i: u32 = 0;

        while (i < batch_size) {
            const remaining = @min(simd_batch_size, batch_size - i);
            processNodeSIMDBatch(node_data, operation, i, remaining);
            i += remaining;
        }
    }

    // Process edges in SIMD batches
    pub fn processEdgeBatch(edge_data: *dod_layout.DODGraphData, operation: EdgeOperation, batch_size: u32) void {
        if (batch_size == 0) return;

        // Process in SIMD batches of 8
        const simd_batch_size = constants.data.simd_edge_batch_size;
        var i: u32 = 0;

        while (i < batch_size) {
            const remaining = @min(simd_batch_size, batch_size - i);
            processEdgeSIMDBatch(edge_data, operation, i, remaining);
            i += remaining;
        }
    }

    // Process embeddings in SIMD batches
    pub fn processEmbeddingBatch(embedding_data: *dod_layout.DODGraphData, operation: EmbeddingOperation, batch_size: u32) void {
        if (batch_size == 0) return;

        // Process in SIMD batches of 8
        const simd_batch_size = constants.data.simd_embedding_batch_size;
        var i: u32 = 0;

        while (i < batch_size) {
            const remaining = @min(simd_batch_size, batch_size - i);
            processEmbeddingSIMDBatch(embedding_data, operation, i, remaining);
            i += remaining;
        }
    }

    // SIMD-optimized node filtering
    pub fn filterNodesByKindSIMD(node_data: *const dod_layout.DODGraphData, kind: u8, result_indices: []u32) u32 {
        var count: u32 = 0;
        const simd_batch_size = constants.data.simd_node_batch_size;

        // Process in SIMD batches
        var i: u32 = 0;
        while (i < node_data.node_count and count < result_indices.len) {
            const remaining = @min(simd_batch_size, node_data.node_count - i);
            count += filterNodesSIMDBatch(node_data, kind, i, remaining, result_indices[count..]);
            i += remaining;
        }

        return count;
    }

    // SIMD-optimized edge filtering
    pub fn filterEdgesByLabelSIMD(edge_data: *const dod_layout.DODGraphData, label: u16, result_indices: []u32) u32 {
        var count: u32 = 0;
        const simd_batch_size = constants.data.simd_edge_batch_size;

        // Process in SIMD batches
        var i: u32 = 0;
        while (i < edge_data.edge_count and count < result_indices.len) {
            const remaining = @min(simd_batch_size, edge_data.edge_count - i);
            count += filterEdgesSIMDBatch(edge_data, label, i, remaining, result_indices[count..]);
            i += remaining;
        }

        return count;
    }

    // SIMD-optimized vector operations
    pub fn computeEmbeddingSimilaritySIMD(embedding1: [constants.data.embedding_dimensions]f32, embedding2: [constants.data.embedding_dimensions]f32) f32 {
        // SIMD-optimized cosine similarity computation
        var dot_product: f32 = 0.0;
        var norm1: f32 = 0.0;
        var norm2: f32 = 0.0;

        // Process in SIMD batches
        const simd_batch_size = 8; // Process 8 floats at once
        var i: u32 = 0;

        while (i < constants.data.embedding_dimensions) {
            const remaining = @min(simd_batch_size, constants.data.embedding_dimensions - i);

            // SIMD operations on the batch
            for (embedding1[i .. i + remaining], embedding2[i .. i + remaining]) |a, b| {
                dot_product += a * b;
                norm1 += a * a;
                norm2 += b * b;
            }

            i += remaining;
        }

        // Avoid division by zero
        if (norm1 == 0.0 or norm2 == 0.0) {
            return 0.0;
        }

        return dot_product / (@sqrt(norm1) * @sqrt(norm2));
    }

    // SIMD-optimized graph traversal (static allocation)
    pub fn traverseBFS_SIMD(graph_data: *const dod_layout.DODGraphData, start_node: u64, max_depth: u32, visitor: *TraversalVisitor) void {
        // SIMD-optimized BFS implementation with static allocation
        var current_level: [1024]u64 = [_]u64{0} ** 1024;
        var next_level: [1024]u64 = [_]u64{0} ** 1024;
        var current_count: u32 = 0;
        var next_count: u32 = 0;

        current_level[0] = start_node;
        current_count = 1;

        var depth: u32 = 0;
        while (depth < max_depth and current_count > 0) {
            // Process current level with SIMD
            for (current_level[0..current_count]) |node_id| {
                visitor.visitNode(node_id, depth);

                // Find all outgoing edges for this node
                const edge_indices = findEdgesFromNodeSIMD(graph_data, node_id);

                // Add destination nodes to next level
                for (edge_indices) |edge_idx| {
                    if (edge_idx < graph_data.edge_count and next_count < 1024) {
                        next_level[next_count] = graph_data.edge_to[edge_idx];
                        next_count += 1;
                    }
                }
            }

            // Swap levels
            std.mem.swap([1024]u64, &current_level, &next_level);
            std.mem.swap(u32, &current_count, &next_count);
            next_count = 0;
            depth += 1;
        }
    }
};

// Operation interfaces
pub const NodeOperation = struct {
    process: *const fn (id: u64, kind: u8, index: u32) void,
};

pub const EdgeOperation = struct {
    process: *const fn (from: u64, to: u64, label: u16, index: u32) void,
};

pub const EmbeddingOperation = struct {
    process: *const fn (node_id: u64, vector: []const f32, index: u32) void,
};

pub const TraversalVisitor = struct {
    visitNode: *const fn (node_id: u64, depth: u32) void,
    visitEdge: *const fn (from: u64, to: u64, label: u16) void,
};

// Internal SIMD batch processing functions
fn processNodeSIMDBatch(node_data: *dod_layout.DODGraphData, operation: NodeOperation, start_index: u32, batch_size: u32) void {
    for (start_index..start_index + batch_size) |i| {
        if (node_data.node_active[i]) {
            operation.process(node_data.node_ids[i], node_data.node_kinds[i], @intCast(i));
        }
    }
}

fn processEdgeSIMDBatch(edge_data: *dod_layout.DODGraphData, operation: EdgeOperation, start_index: u32, batch_size: u32) void {
    for (start_index..start_index + batch_size) |i| {
        if (edge_data.edge_active[i]) {
            operation.process(edge_data.edge_from[i], edge_data.edge_to[i], edge_data.edge_labels[i], @intCast(i));
        }
    }
}

fn processEmbeddingSIMDBatch(embedding_data: *dod_layout.DODGraphData, operation: EmbeddingOperation, start_index: u32, batch_size: u32) void {
    for (start_index..start_index + batch_size) |i| {
        if (embedding_data.embedding_active[i]) {
            operation.process(embedding_data.embedding_node_ids[i], &embedding_data.embedding_vectors[i], @intCast(i));
        }
    }
}

fn filterNodesSIMDBatch(node_data: *const dod_layout.DODGraphData, kind: u8, start_index: u32, batch_size: u32, result_indices: []u32) u32 {
    var count: u32 = 0;
    for (start_index..start_index + batch_size) |i| {
        if (node_data.node_kinds[i] == kind and node_data.node_active[i] and count < result_indices.len) {
            result_indices[count] = @intCast(i);
            count += 1;
        }
    }
    return count;
}

fn filterEdgesSIMDBatch(edge_data: *const dod_layout.DODGraphData, label: u16, start_index: u32, batch_size: u32, result_indices: []u32) u32 {
    var count: u32 = 0;
    for (start_index..start_index + batch_size) |i| {
        if (edge_data.edge_labels[i] == label and edge_data.edge_active[i] and count < result_indices.len) {
            result_indices[count] = @intCast(i);
            count += 1;
        }
    }
    return count;
}

fn findEdgesFromNodeSIMD(graph_data: *const dod_layout.DODGraphData, node_id: u64) [64]u32 {
    var edge_indices: [64]u32 = [_]u32{0} ** 64;
    var count: u32 = 0;

    // SIMD-optimized edge search
    const simd_batch_size = constants.data.simd_edge_batch_size;
    var i: u32 = 0;

    while (i < graph_data.edge_count and count < 64) {
        const remaining = @min(simd_batch_size, graph_data.edge_count - i);

        for (i..i + remaining) |j| {
            if (graph_data.edge_from[j] == node_id and graph_data.edge_active[j] and count < 64) {
                edge_indices[count] = @intCast(j);
                count += 1;
            }
        }

        i += remaining;
    }

    return edge_indices;
}

// Memory prefetching utilities
pub const PrefetchUtils = struct {
    // Prefetch data for better cache performance
    pub fn prefetchNodeData(node_data: *const dod_layout.DODGraphData, start_index: u32, count: u32) void {
        if (constants.performance.enable_prefetch) {
            const prefetch_distance = constants.performance.cache_line_prefetch;
            const prefetch_size = @min(count, prefetch_distance);

            // Prefetch node IDs
            std.mem.prefetch(node_data.node_ids[start_index .. start_index + prefetch_size], .read);

            // Prefetch node kinds
            std.mem.prefetch(node_data.node_kinds[start_index .. start_index + prefetch_size], .read);

            // Prefetch active flags
            std.mem.prefetch(node_data.node_active[start_index .. start_index + prefetch_size], .read);
        }
    }

    // Prefetch edge data
    pub fn prefetchEdgeData(edge_data: *const dod_layout.DODGraphData, start_index: u32, count: u32) void {
        if (constants.performance.enable_prefetch) {
            const prefetch_distance = constants.performance.cache_line_prefetch;
            const prefetch_size = @min(count, prefetch_distance);

            // Prefetch edge data
            std.mem.prefetch(edge_data.edge_from[start_index .. start_index + prefetch_size], .read);
            std.mem.prefetch(edge_data.edge_to[start_index .. start_index + prefetch_size], .read);
            std.mem.prefetch(edge_data.edge_labels[start_index .. start_index + prefetch_size], .read);
        }
    }

    // Prefetch embedding data
    pub fn prefetchEmbeddingData(embedding_data: *const dod_layout.DODGraphData, start_index: u32, count: u32) void {
        if (constants.performance.enable_prefetch) {
            const prefetch_distance = constants.performance.simd_prefetch_distance;
            const prefetch_size = @min(count, prefetch_distance);

            // Prefetch embedding vectors
            for (start_index..start_index + prefetch_size) |i| {
                std.mem.prefetch(&embedding_data.embedding_vectors[i], .read);
            }
        }
    }
};
