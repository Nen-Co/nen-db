// Minimal NenDB Test
const std = @import("std");
const nendb = @import("lib_v2.zig");

pub fn main() !void {
    std.debug.print("🧪 Starting minimal NenDB test...\n", .{});
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    std.debug.print("✓ Allocator created\n", .{});
    
    const config = nendb.Config{
        .data_dir = "./test_data",
    };
    
    std.debug.print("✓ Config created\n", .{});
    
    var db = nendb.create(allocator, config) catch |err| {
        std.debug.print("❌ Database creation failed: {}\n", .{err});
        return;
    };
    defer db.deinit();
    
    std.debug.print("✅ Database created successfully!\n", .{});
    
    const stats = db.get_stats();
    std.debug.print("📊 Memory usage: {d} bytes\n", .{stats.total_memory_bytes});
    
    std.debug.print("🎉 Minimal test completed!\n", .{});
}
