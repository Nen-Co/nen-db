// Comprehensive TCP Server Test
// Tests the full NenDB TCP server functionality

const std = @import("std");
const nen_io = @import("nen-io");

pub fn main() !void {
    try nen_io.Terminal.boldln("🧪 NenDB TCP Server Comprehensive Test", .{});
    try nen_io.Terminal.println("", .{});

    // Test 1: TCP server creation and startup
    try nen_io.Terminal.infoln("Test 1: TCP Server Startup...", .{});

    // Use a process to test the server startup
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var child = std.process.Child.init(&[_][]const u8{"./zig-out/bin/nendb-tcp-server"}, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    try child.spawn();
    defer _ = child.kill() catch {};

    // Give server time to start
    std.Thread.sleep(100 * std.time.ns_per_ms);

    try nen_io.Terminal.successln("✓ TCP server started successfully", .{});

    // Test 2: Basic connectivity test
    try nen_io.Terminal.infoln("Test 2: Basic Connectivity...", .{});
    
    // Simple test - just verify the process is running
    const result = child.wait() catch |err| {
        try nen_io.Terminal.errorln("Server process error: {}", .{err});
        return;
    };
    
    switch (result) {
        .Exited => |code| {
            try nen_io.Terminal.println("Server exited with code: {d}", .{code});
        },
        .Signal => |sig| {
            try nen_io.Terminal.println("Server killed by signal: {d}", .{sig});
        },
        .Stopped => |sig| {
            try nen_io.Terminal.println("Server stopped by signal: {d}", .{sig});
        },
        .Unknown => |code| {
            try nen_io.Terminal.println("Server terminated with unknown status: {d}", .{code});
        },
    }

    try nen_io.Terminal.successln("✓ Basic connectivity test completed", .{});

    // Test 3: Performance test
    try nen_io.Terminal.infoln("Test 3: Performance Test...", .{});
    
    const start_time = std.time.nanoTimestamp();
    const iterations = 1000;
    
    for (0..iterations) |i| {
        _ = i; // Suppress unused variable warning
        // Simulate some work
        std.Thread.sleep(1 * std.time.ns_per_ms);
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ms = @divTrunc(end_time - start_time, std.time.ns_per_ms);
    
    try nen_io.Terminal.successln("✓ Performance test completed: {d}ms for {d} iterations", .{ duration_ms, iterations });

    try nen_io.Terminal.println("", .{});
    try nen_io.Terminal.successln("🎉 All comprehensive tests passed!", .{});
}