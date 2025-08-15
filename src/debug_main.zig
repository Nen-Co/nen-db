// Super minimal debug main to isolate the issue

const std = @import("std");
const pool = @import("memory/pool_v2.zig");
const constants = @import("constants.zig");

pub fn main() !void {
    std.debug.print("Starting debug main...\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    std.debug.print("Allocator created...\n", .{});
    
    // TigerBeetle-style: statically aligned, zero-initialized node pool
    const node_pool: pool.NodePool align(64) = pool.NodePool.init();
    _ = node_pool;
    std.debug.print("Node pool initialized and aligned to 64 bytes.\n", .{});

    // const edge_pool: pool.EdgePool align(64) = pool.EdgePool.init();
    // _ = edge_pool;
    // std.debug.print("Edge pool initialized and aligned to 64 bytes.\n", .{});

    const Embedding = pool.Embedding;
    const EMBEDDING_POOL_SIZE = constants.memory.embedding_pool_size;
    const EMBEDDING_DIM = constants.data.embedding_dimensions;
    std.debug.print("sizeof(Embedding): {} bytes\n", .{@sizeOf(Embedding)});
    std.debug.print("Embedding pool size: {}\n", .{EMBEDDING_POOL_SIZE});
    std.debug.print("Embedding dimension: {}\n", .{EMBEDDING_DIM});
    std.debug.print("Total embedding pool bytes: {}\n", .{@sizeOf(Embedding) * EMBEDDING_POOL_SIZE});
    const embedding_pool: pool.EmbeddingPool align(64) = pool.EmbeddingPool.init();
    _ = embedding_pool;
    std.debug.print("Embedding pool initialized and aligned to 64 bytes.\n", .{});
    std.debug.print("Debug test completed!\n", .{});
}
