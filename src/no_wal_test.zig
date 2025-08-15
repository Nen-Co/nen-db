// Test without WAL
const std = @import("std");
const constants = @import("constants.zig");
const pool = @import("memory/pool_v2.zig");

pub fn main() !void {
    std.debug.print("🧪 Testing without WAL...\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    std.debug.print("✓ Allocator created\n", .{});
    
    // Test pool creation
    var node_pool = pool.NodePool.init();
    _ = pool.EdgePool.init();
    _ = pool.EmbeddingPool.init();
    
    std.debug.print("✓ All pools created\n", .{});
    
    // Test node allocation
    const test_node = pool.Node{
        .id = 1001,
        .kind = 1,
        .props = [_]u8{'T','e','s','t',' ','N','o','d','e'} ++ [_]u8{0} ** (constants.data.node_props_size - 9),
    };
    
    const node_idx = node_pool.alloc(test_node) catch |err| {
        std.debug.print("❌ Node allocation failed: {}\n", .{err});
        return;
    };
    
    std.debug.print("✓ Node allocated at index: {d}\n", .{node_idx});
    
    // Test node retrieval
    const retrieved_node = node_pool.get(node_idx) orelse {
        std.debug.print("❌ Node retrieval failed\n", .{});
        return;
    };
    
    std.debug.print("✓ Node retrieved: id={d}, kind={d}\n", .{retrieved_node.id, retrieved_node.kind});
    
    std.debug.print("🎉 WAL-free test passed!\n", .{});
}
