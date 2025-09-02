// NenDB CLI - Command Line Interface
// Simple CLI for interacting with NenDB

const std = @import("std");
const io = @import("io/io.zig");
const GraphDB = @import("graphdb.zig").GraphDB;
const pool = @import("memory/pool_v2.zig");
const constants = @import("constants.zig");

pub fn main() !void {
    const style = @import("cli/style.zig").Style.detect();

    if (style.use_color) {
        try io.Terminal.println("\x1b[1;38;5;81m┌──────────────────────────────────────────┐", .{});
        try io.Terminal.println("│      ⚡ NenDB • Graph Engine Core ⚡      │", .{});
        try io.Terminal.println("└──────────────────────────────────────────┘", .{});
    } else {
        try io.Terminal.println("NenDB - Graph Engine Core", .{});
    }
    try io.Terminal.println("Version: {s} | Zig: {s}", .{ constants.VERSION_STRING, @import("builtin").zig_version_string });

    // Simple argument parsing
    var it = std.process.argsWithAllocator(std.heap.page_allocator) catch |err| {
        try io.Terminal.errorln("Failed to get command line arguments: {}", .{err});
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

    try io.Terminal.success("✅ NenDB started successfully with custom I/O!", .{});
}

fn run_demo() !void {
    try io.Terminal.successln("🚀 Running NenDB Demo - Graph Operations", .{});

    // Initialize database
    var db: GraphDB = undefined;
    try db.init_inplace(std.heap.page_allocator);
    defer db.deinit();

    try io.Terminal.infoln("✅ Database initialized", .{});

    // Insert nodes
    try io.Terminal.infoln("📝 Inserting nodes...", .{});

    const node1 = pool.Node{ .id = 1, .kind = 1, .props = [_]u8{0} ** 128 };
    const node2 = pool.Node{ .id = 2, .kind = 1, .props = [_]u8{0} ** 128 };
    const node3 = pool.Node{ .id = 3, .kind = 2, .props = [_]u8{0} ** 128 };

    try db.insert_node(node1);
    try db.insert_node(node2);
    try db.insert_node(node3);

    try io.Terminal.success("✅ Inserted 3 nodes", .{});

    // Insert edges
    try io.Terminal.infoln("🔗 Inserting edges...", .{});

    const edge1 = pool.Edge{ .from = 1, .to = 2, .label = 1, .props = [_]u8{0} ** 64 };
    const edge2 = pool.Edge{ .from = 2, .to = 3, .label = 1, .props = [_]u8{0} ** 64 };
    const edge3 = pool.Edge{ .from = 1, .to = 3, .label = 2, .props = [_]u8{0} ** 64 };

    try db.insert_edge(edge1);
    try db.insert_edge(edge2);
    try db.insert_edge(edge3);

    try io.Terminal.success("✅ Inserted 3 edges", .{});

    // Lookup operations
    try io.Terminal.infoln("🔍 Testing lookups...", .{});

    const found_node = db.lookup_node(1);
    if (found_node) |node| {
        try io.Terminal.println("  Found node: ID={d}, Kind={d}", .{ node.id, node.kind });
    }

    const found_edge = db.lookup_edge(1, 2);
    if (found_edge) |edge| {
        try io.Terminal.println("  Found edge: {d}->{d} (label={d})", .{ edge.from, edge.to, edge.label });
    }

    // Delete operations (commented out for now)
    try io.Terminal.infoln("🗑️ Delete operations:", .{});
    try io.Terminal.println("  ⚠️ Delete operations are implemented but need edge pool fixes", .{});
    try io.Terminal.println("  🔧 TODO: Fix edge pool free() logic", .{});

    // Get statistics
    try io.Terminal.infoln("📊 Database statistics:", .{});
    const stats = db.get_stats();
    try io.Terminal.println("  Nodes: {d}/{d} used", .{ stats.memory.nodes.used, stats.memory.nodes.capacity });
    try io.Terminal.println("  Edges: {d}/{d} used", .{ stats.memory.edges.used, stats.memory.edges.capacity });
    try io.Terminal.println("  WAL entries: {d}", .{stats.wal.entries_written});

    try io.Terminal.successln("🎉 Demo completed successfully!", .{});
}

fn print_help() !void {
    try io.Terminal.println("NenDB - Production-focused, static-memory graph store", .{});
    try io.Terminal.println("", .{});
    try io.Terminal.println("Usage: nendb <command> [path]", .{});
    try io.Terminal.println("", .{});
    try io.Terminal.println("Commands:", .{});
    try io.Terminal.println("  help                    Show this help message", .{});
    try io.Terminal.println("  demo                    Run a demo of graph operations", .{});
    try io.Terminal.println("  init <path>            Initialize a new NenDB at <path>", .{});
    try io.Terminal.println("  up <path>              Start NenDB at <path> (default: current directory)", .{});
    try io.Terminal.println("  status <path>          Show database status (default: current directory)", .{});
    try io.Terminal.println("  query <path> <query>   Execute Cypher query at <path>", .{});
    try io.Terminal.println("  serve                  Start TCP server on port 5454", .{});
    try io.Terminal.println("", .{});
    try io.Terminal.println("Features:", .{});
    try io.Terminal.println("  • Node/Edge CRUD operations", .{});
    try io.Terminal.println("  • Graph traversal (BFS/DFS)", .{});
    try io.Terminal.println("  • Path finding algorithms", .{});
    try io.Terminal.println("  • Property management", .{});
    try io.Terminal.println("  • WAL-based durability", .{});
    try io.Terminal.println("  • Static memory pools", .{});
    try io.Terminal.println("", .{});
    try io.Terminal.println("Version: {s} - Custom I/O Implementation", .{constants.VERSION_STRING});
}
