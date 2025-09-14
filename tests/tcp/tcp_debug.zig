const std = @import("std");
const nendb = @import("nendb");
const io = nendb.io;
const graphdb = nendb.graphdb;
const nen_net = @import("nen-net");

pub fn main() !void {
    try io.terminal.successln("🔍 TCP Debug Test Starting...", .{});

    // Test 1: Basic TCP server creation
    try io.terminal.infoln("Test 1: Creating TCP server...", .{});
    var server = nen_net.createTcpServer(8080) catch |err| {
        try io.terminal.errorln("Failed to create TCP server: {}", .{err});
        return;
    };
    try io.terminal.successln("✓ TCP server created successfully", .{});

    // Test 2: Bind test
    try io.terminal.infoln("Test 2: Binding to port...", .{});
    server.bind() catch |err| {
        try io.terminal.errorln("Failed to bind: {}", .{err});
        return;
    };
    try io.terminal.successln("✓ Bound to port successfully", .{});

    // Test 3: GraphDB initialization
    try io.terminal.infoln("Test 3: Initializing GraphDB...", .{});
    var graph_db: graphdb.GraphDB = undefined;
    graph_db.init_inplace(std.heap.page_allocator) catch |err| {
        try io.terminal.errorln("Failed to initialize GraphDB: {}", .{err});
        return;
    };
    defer graph_db.deinit();
    try io.terminal.successln("✓ GraphDB initialized successfully", .{});

    try io.terminal.successln("🎉 All TCP tests passed!", .{});
}
