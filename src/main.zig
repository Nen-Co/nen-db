const std = @import("std");
const nendb = @import("nendb");

// Extract types from nendb lib
const GraphDB = nendb.GraphDB;
const constants = nendb.constants;

// Use std.debug.print for CI compatibility
const Terminal = struct {
    pub inline fn boldln(comptime format: []const u8, args: anytype) !void {
        std.debug.print(format ++ "\n", args);
    }
    pub inline fn println(comptime format: []const u8, args: anytype) !void {
        std.debug.print(format ++ "\n", args);
    }
    pub inline fn infoln(comptime format: []const u8, args: anytype) !void {
        std.debug.print(format ++ "\n", args);
    }
    pub inline fn successln(comptime format: []const u8, args: anytype) !void {
        std.debug.print(format ++ "\n", args);
    }
    pub inline fn errorln(comptime format: []const u8, args: anytype) !void {
        std.debug.print(format ++ "\n", args);
    }
    pub inline fn warnln(comptime format: []const u8, args: anytype) !void {
        std.debug.print(format ++ "\n", args);
    }
    pub inline fn print(comptime format: []const u8, args: anytype) !void {
        std.debug.print(format, args);
    }
};

pub fn main() !void {
    try Terminal.boldln("┌──────────────────────────────────────────┐", .{});
    try Terminal.boldln("│      ⚡ NenDB • Graph Engine Core ⚡      │", .{});
    try Terminal.boldln("└──────────────────────────────────────────┘", .{});
    try Terminal.println("Version: {s} | Zig: {s}", .{ constants.VERSION_STRING, @import("builtin").zig_version_string });

    // Simple argument parsing
    var it = std.process.argsWithAllocator(std.heap.page_allocator) catch |err| {
        try Terminal.errorln("Failed to get command line arguments: {}", .{err});
        try print_help();
        return;
    };
    defer it.deinit();
    _ = it.next(); // skip program name

    const arg = it.next() orelse {
        try print_help();
        return;
    };

    if (std.mem.eql(u8, arg, "help") or std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
        try print_help();
        return;
    }

    if (std.mem.eql(u8, arg, "demo")) {
        try run_demo();
        return;
    }

    if (std.mem.eql(u8, arg, "init")) {
        const path = it.next() orelse {
            try Terminal.errorln("❌ Error: init requires a path", .{});
            try Terminal.println("Usage: nendb init <path>", .{});
            return;
        };
        try init_database(path);
        return;
    }

    if (std.mem.eql(u8, arg, "serve")) {
        try run_interactive_server();
        return;
    }

    try Terminal.successln("✅ NenDB started successfully with custom I/O!", .{});
}

fn run_demo() !void {
    try Terminal.infoln("🚀 Running NenDB Demo - Graph Operations", .{});

    // Initialize database using lib interface
    var db = nendb.init() catch |err| {
        try Terminal.errorln("❌ Failed to initialize database: {}", .{err});
        return;
    };
    defer db.deinit();

    try Terminal.successln("✅ Database initialized", .{});

    // Insert nodes
    try Terminal.infoln("📝 Inserting nodes...", .{});
    try db.insert_node(1, 1); // ID=1, Kind=1
    try db.insert_node(2, 2); // ID=2, Kind=2
    try db.insert_node(3, 1); // ID=3, Kind=1

    try Terminal.successln("✅ Inserted 3 nodes", .{});

    // Insert edges
    try Terminal.infoln("🔗 Inserting edges...", .{});
    try db.insert_edge(1, 2, 1); // 1->2 with label 1
    try db.insert_edge(2, 3, 2); // 2->3 with label 2
    try db.insert_edge(3, 1, 3); // 3->1 with label 3

    try Terminal.successln("✅ Inserted 3 edges", .{});

    // Test lookups
    try Terminal.infoln("🔍 Testing lookups...", .{});
    if (db.lookup_node(1)) |node_id| {
        try Terminal.println("  Found node: ID=1, Node ID={d}", .{node_id});
    }
    if (db.lookup_node(2)) |node_id| {
        try Terminal.println("  Found node: ID=2, Node ID={d}", .{node_id});
    }
    if (db.lookup_node(3)) |node_id| {
        try Terminal.println("  Found node: ID=3, Node ID={d}", .{node_id});
    }

    // Note: Edge lookups are commented out due to current implementation
    //     try Terminal.println("  Found edge: {d}->{d} (label={d})", .{ edge.from, edge.to, edge.label });

    // Show statistics
    const stats = db.get_stats();
    try Terminal.infoln("📊 Database statistics:", .{});
    try Terminal.println("  Nodes: {d}/{d} used", .{ stats.memory.nodes.node_count, stats.memory.nodes.node_capacity });
    try Terminal.println("  Edges: {d}/{d} used", .{ stats.memory.nodes.edge_count, stats.memory.nodes.edge_capacity });
    try Terminal.println("  Overall utilization: {d:.2}%", .{stats.memory.nodes.getUtilization() * 100.0});

    try Terminal.successln("🎉 Demo completed successfully!", .{});
}

fn print_help() !void {
    try Terminal.println("NenDB - Production-focused, static-memory graph store", .{});
    try Terminal.println("", .{});
    try Terminal.println("Usage: nendb <command> [path]", .{});
    try Terminal.println("", .{});
    try Terminal.println("Commands:", .{});
    try Terminal.println("  help                    Show this help message", .{});
    try Terminal.println("  demo                    Run a demo of graph operations", .{});
    try Terminal.println("  init <path>            Initialize a new NenDB at <path>", .{});
    try Terminal.println("  up <path>              Start NenDB at <path> (default: current directory)", .{});
    try Terminal.println("  status <path>          Show database status (default: current directory)", .{});
    try Terminal.println("  query <path> <query>   Execute Cypher query at <path>", .{});
    try Terminal.println("  serve                  Start TCP server on port 5454", .{});
    try Terminal.println("", .{});
    try Terminal.println("Features:", .{});
    try Terminal.println("  • Node/Edge CRUD operations", .{});
    try Terminal.println("  • Graph traversal (BFS/DFS)", .{});
    try Terminal.println("  • Path finding algorithms", .{});
    try Terminal.println("  • Property management", .{});
    try Terminal.println("  • WAL-based durability", .{});
    try Terminal.println("  • Static memory pools", .{});
    try Terminal.println("", .{});
    try Terminal.println("Version: {s} - Custom I/O Implementation", .{constants.VERSION_STRING});
}

fn init_database(path: []const u8) !void {
    try Terminal.infoln("📁 Initializing NenDB at: {s}", .{path});

    // Create directory if it doesn't exist
    std.fs.cwd().makeDir(path) catch |err| switch (err) {
        error.PathAlreadyExists => {}, // Directory already exists, that's fine
        else => {
            try Terminal.errorln("❌ Failed to create directory: {}", .{err});
            return;
        },
    };

    // Initialize database using the lib interface
    var db = nendb.open(path) catch |err| {
        try Terminal.errorln("❌ Failed to initialize database: {}", .{err});
        return;
    };
    defer db.deinit();

    try Terminal.successln("✅ NenDB initialized at: {s}", .{path});
    try Terminal.infoln("  • Database file: {s}/nendb.db", .{path});
    try Terminal.infoln("  • WAL file: {s}/nendb.wal", .{path});
}

fn run_interactive_server() !void {
    try Terminal.infoln("🌐 Starting NenDB HTTP Server...", .{});

    // Initialize database
    var db = nendb.init() catch |err| {
        try Terminal.errorln("❌ Failed to initialize database: {}", .{err});
        return;
    };
    defer db.deinit();

    try Terminal.successln("✅ Database initialized", .{});

    // Check if networking is supported (not available in WASM)
    if (comptime @import("builtin").target.os.tag == .wasi) {
        try Terminal.errorln("❌ HTTP server not supported in WASM environment", .{});
        try Terminal.infoln("💡 Use the native build for HTTP server functionality", .{});
        return;
    }

    // Create a simple HTTP server using std.net
    const address = std.net.Address.parseIp4("127.0.0.1", 8080) catch |err| {
        try Terminal.errorln("❌ Failed to parse address: {}", .{err});
        return;
    };

    var server = address.listen(.{ .reuse_address = true }) catch |err| {
        try Terminal.errorln("❌ Failed to start server: {}", .{err});
        return;
    };

    try Terminal.successln("✅ HTTP server configured", .{});
    try Terminal.infoln("🚀 NenDB HTTP Server running", .{});
    try Terminal.infoln("  • Server: http://localhost:8080", .{});
    try Terminal.infoln("  • Health: http://localhost:8080/health", .{});
    try Terminal.infoln("  • Stats: http://localhost:8080/graph/stats", .{});
    try Terminal.infoln("  • Press Ctrl+C to stop", .{});

    // Show initial status
    const initial_stats = db.get_stats();
    try Terminal.println("  Initial Status: {d} nodes, {d} edges, {d:.2}% utilization", .{ initial_stats.memory.nodes.node_count, initial_stats.memory.nodes.edge_count, initial_stats.memory.nodes.getUtilization() * 100.0 });

    try Terminal.successln("🌐 HTTP Server started on port 8080", .{});

    // Simple HTTP server loop
    while (true) {
        const connection = server.accept() catch |err| {
            try Terminal.warnln("⚠️  Connection error: {}", .{err});
            continue;
        };
        defer connection.stream.close();

        // Handle the request in a simple way
        handleHttpRequest(connection, &db) catch |err| {
            try Terminal.warnln("⚠️  Request handling error: {}", .{err});
        };
    }
}

fn handleHttpRequest(connection: std.net.Server.Connection, db: *nendb.Database) !void {
    var buffer: [4096]u8 = undefined;
    const bytes_read = connection.stream.read(&buffer) catch |err| {
        try Terminal.warnln("⚠️  Read error: {}", .{err});
        return;
    };

    const request = buffer[0..bytes_read];

    // Simple HTTP parsing
    if (std.mem.indexOf(u8, request, "GET /health")) |_| {
        const response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 67\r\n\r\n{\"status\":\"healthy\",\"service\":\"nendb\",\"version\":\"v0.2.1-beta\"}";
        _ = connection.stream.write(response) catch |err| {
            try Terminal.warnln("⚠️  Write error: {}", .{err});
        };
    } else if (std.mem.indexOf(u8, request, "GET /graph/stats")) |_| {
        const stats = db.get_stats();
        const response = try std.fmt.allocPrint(std.heap.page_allocator, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n\r\n{{\"nodes\":{d},\"edges\":{d},\"utilization\":{d:.2}}}", .{ 50, stats.memory.nodes.node_count, stats.memory.nodes.edge_count, stats.memory.nodes.getUtilization() * 100.0 });
        defer std.heap.page_allocator.free(response);
        _ = connection.stream.write(response) catch |err| {
            try Terminal.warnln("⚠️  Write error: {}", .{err});
        };
    } else {
        const response = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\n404 Not Found";
        _ = connection.stream.write(response) catch |err| {
            try Terminal.warnln("⚠️  Write error: {}", .{err});
        };
    }
}
