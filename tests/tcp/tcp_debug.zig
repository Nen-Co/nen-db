// TCP Debug Test
// Simple test to verify TCP server functionality

const std = @import("std");
const io = @import("nen-io");

pub fn main() !void {
    std.debug.print("🔍 TCP Debug Test Starting...\n", .{});

    std.debug.print("Test 1: Creating TCP server...\n", .{});
    const server = io.createTcpServer() catch |err| {
        std.debug.print("Failed to create TCP server: {}\n", .{err});
        return;
    };
    std.debug.print("✓ TCP server created successfully\n", .{});

    std.debug.print("Test 2: Binding to port...\n", .{});
    server.bind(5454) catch |err| {
        std.debug.print("Failed to bind: {}\n", .{err});
        return;
    };
    std.debug.print("✓ Bound to port successfully\n", .{});

    std.debug.print("Test 3: Initializing GraphDB...\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const GraphDB = @import("../../src/graphdb.zig").GraphDB;
    var db = GraphDB.init(allocator) catch |err| {
        std.debug.print("Failed to initialize GraphDB: {}\n", .{err});
        return;
    };
    defer db.deinit();

    std.debug.print("✓ GraphDB initialized successfully\n", .{});

    std.debug.print("🎉 All TCP tests passed!\n", .{});
}