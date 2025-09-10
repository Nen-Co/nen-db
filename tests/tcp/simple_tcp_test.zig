// Simple TCP server test to debug the segfault
const std = @import("std");

pub fn main() !void {
    std.debug.print("🔍 Simple TCP Test Starting...\n", .{});

    // Test basic allocation
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    _ = gpa.allocator(); // Just to test allocator works

    std.debug.print("✓ Allocator initialized\n", .{});

    // Test network address creation
    const address = std.net.Address.parseIp4("127.0.0.1", 8080) catch |err| {
        std.debug.print("❌ Address parse failed: {}\n", .{err});
        return;
    };
    std.debug.print("✓ Address parsed: 127.0.0.1:8080\n", .{});

    // Test socket creation
    const socket = std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0) catch |err| {
        std.debug.print("❌ Socket creation failed: {}\n", .{err});
        return;
    };
    defer std.posix.close(socket);
    std.debug.print("✓ Socket created\n", .{});

    // Test binding
    std.posix.bind(socket, &address.any, address.getOsSockLen()) catch |err| {
        std.debug.print("❌ Bind failed: {}\n", .{err});
        return;
    };
    std.debug.print("✓ Socket bound to port 8080\n", .{});

    std.debug.print("🎉 All basic TCP tests passed!\n", .{});
}
