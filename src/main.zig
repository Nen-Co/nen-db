const std = @import("std");
const GraphDB = @import("graphdb.zig").GraphDB;
const layout = @import("memory/layout.zig");
const constants = @import("constants.zig");

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

    try Terminal.successln("✅ NenDB started successfully with custom I/O!", .{});
}

fn run_demo() !void {
    try Terminal.infoln("🚀 Running NenDB Demo - Graph Operations", .{});

    // Initialize database
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = GraphDB{
        .mutex = .{},
        .graph_data = undefined,
        .simd_processor = undefined,
        .ops_since_snapshot = 0,
        .inserts_total = 0,
        .read_seq = undefined,
        .lookups_total = undefined,
        .allocator = allocator,
        .wal = undefined,
        .db_path = "demo-db",
    };
    try db.init_inplace(allocator, "demo-db");
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

    // Initialize a real database to create the files
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = GraphDB{
        .mutex = .{},
        .graph_data = undefined,
        .simd_processor = undefined,
        .ops_since_snapshot = 0,
        .inserts_total = 0,
        .read_seq = undefined,
        .lookups_total = undefined,
        .allocator = allocator,
        .wal = undefined,
        .db_path = path,
    };
    try db.init_inplace(allocator, path);
    defer db.deinit();

    try Terminal.successln("✅ NenDB initialized at: {s}", .{path});
    try Terminal.infoln("  • Database file: {s}/nendb.db", .{path});
    try Terminal.infoln("  • WAL file: {s}/nendb.wal", .{path});
}
