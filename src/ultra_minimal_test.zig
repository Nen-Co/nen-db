// Ultra minimal test
const std = @import("std");

pub fn main() !void {
    std.debug.print("🧪 Ultra minimal test starting...\n", .{});
    
    // Test constants import
    const constants = @import("constants.zig");
    std.debug.print("✓ Constants imported\n", .{});
    std.debug.print("  - Node pool size: {d}\n", .{constants.memory.node_pool_size});
    
    // Test pool import
    const pool = @import("memory/pool_v2.zig");
    std.debug.print("✓ Pool imported\n", .{});
    
    // Try to create a NodePool
    var node_pool = pool.NodePool.init();
    std.debug.print("✓ NodePool created\n", .{});
    
    const stats = node_pool.get_stats();
    std.debug.print("✓ Stats retrieved: {d}/{d}\n", .{stats.used, stats.capacity});
    
    std.debug.print("🎉 Ultra minimal test passed!\n", .{});
}
