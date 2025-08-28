// NenDB CLI - Command Line Interface
// Simple CLI for interacting with NenDB

const std = @import("std");
const io = @import("io/io.zig");
const GraphDB = @import("graphdb.zig").GraphDB;
const pool = @import("memory/pool_v2.zig");

pub fn main() !void {
    const style = @import("cli/style.zig").Style.detect();
    
    if (style.use_color) {
        io.Terminal.println("\x1b[1;38;5;81m┌──────────────────────────────────────────┐", .{});
        io.Terminal.println("│      ⚡ NenDB • Graph Engine Core ⚡      │", .{});
        io.Terminal.println("└──────────────────────────────────────────┘", .{});
    } else {
        io.Terminal.println("NenDB - Graph Engine Core", .{});
    }
    io.Terminal.println("Version: 0.0.1 (Beta) | Zig: {s}", .{@import("builtin").zig_version_string});

    // Simple argument parsing
    var it = std.process.args();
    _ = it.next(); // skip program name

    const arg = it.next() orelse {
        print_help();
        return;
    };

    if (std.mem.eql(u8, arg, "help") or std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
        print_help();
        return;
    }

    if (std.mem.eql(u8, arg, "demo")) {
        try run_demo();
        return;
    }

    io.Terminal.success("✅ NenDB started successfully with custom I/O!", .{});
}

fn run_demo() !void {
    io.Terminal.successln("🚀 Running NenDB Demo - Graph Operations", .{});
    
    // Initialize database
    var db: GraphDB = undefined;
    try db.init_inplace();
    defer db.deinit();
    
    io.Terminal.infoln("✅ Database initialized", .{});
    
    // Insert nodes
    io.Terminal.infoln("📝 Inserting nodes...", .{});
    
    const node1 = pool.Node{ .id = 1, .kind = 1, .props = [_]u8{0} ** 128 };
    const node2 = pool.Node{ .id = 2, .kind = 1, .props = [_]u8{0} ** 128 };
    const node3 = pool.Node{ .id = 3, .kind = 2, .props = [_]u8{0} ** 128 };
    
    try db.insert_node(node1);
    try db.insert_node(node2);
    try db.insert_node(node3);
    
    io.Terminal.success("✅ Inserted 3 nodes", .{});
    
    // Insert edges
    io.Terminal.infoln("🔗 Inserting edges...", .{});
    
    const edge1 = pool.Edge{ .from = 1, .to = 2, .label = 1, .props = [_]u8{0} ** 64 };
    const edge2 = pool.Edge{ .from = 2, .to = 3, .label = 1, .props = [_]u8{0} ** 64 };
    const edge3 = pool.Edge{ .from = 1, .to = 3, .label = 2, .props = [_]u8{0} ** 64 };
    
    try db.insert_edge(edge1);
    try db.insert_edge(edge2);
    try db.insert_edge(edge3);
    
    io.Terminal.success("✅ Inserted 3 edges", .{});
    
    // Lookup operations
    io.Terminal.infoln("🔍 Testing lookups...", .{});
    
    const found_node = db.lookup_node(1);
    if (found_node) |node| {
        io.Terminal.println("  Found node: ID={d}, Kind={d}", .{node.id, node.kind});
    }
    
    const found_edge = db.lookup_edge(1, 2);
    if (found_edge) |edge| {
        io.Terminal.println("  Found edge: {d}->{d} (label={d})", .{edge.from, edge.to, edge.label});
    }
    
    // Delete operations (commented out for now)
    io.Terminal.infoln("🗑️ Delete operations:", .{});
    io.Terminal.println("  ⚠️ Delete operations are implemented but need edge pool fixes", .{});
    io.Terminal.println("  🔧 TODO: Fix edge pool free() logic", .{});
    
    // Get statistics
    io.Terminal.infoln("📊 Database statistics:", .{});
    const stats = db.get_stats();
    io.Terminal.println("  Nodes: {d}/{d} used", .{stats.memory.nodes.used, stats.memory.nodes.capacity});
    io.Terminal.println("  Edges: {d}/{d} used", .{stats.memory.edges.used, stats.memory.edges.capacity});
    io.Terminal.println("  WAL entries: {d}", .{stats.wal.entries_written});
    
    io.Terminal.successln("🎉 Demo completed successfully!", .{});
}

fn print_help() void {
    io.Terminal.println("NenDB - Production-focused, static-memory graph store", .{});
    io.Terminal.println("", .{});
    io.Terminal.println("Usage: nendb <command> [path]", .{});
    io.Terminal.println("", .{});
    io.Terminal.println("Commands:", .{});
    io.Terminal.println("  help                    Show this help message", .{});
    io.Terminal.println("  demo                    Run a demo of graph operations", .{});
    io.Terminal.println("  init <path>            Initialize a new NenDB at <path>", .{});
    io.Terminal.println("  up <path>              Start NenDB at <path> (default: current directory)", .{});
    io.Terminal.println("  status <path>          Show database status (default: current directory)", .{});
    io.Terminal.println("  query <path> <query>   Execute Cypher query at <path>", .{});
    io.Terminal.println("  serve                  Start TCP server on port 5454", .{});
    io.Terminal.println("", .{});
    io.Terminal.println("Features:", .{});
    io.Terminal.println("  • Node/Edge CRUD operations", .{});
    io.Terminal.println("  • Graph traversal (BFS/DFS)", .{});
    io.Terminal.println("  • Path finding algorithms", .{});
    io.Terminal.println("  • Property management", .{});
    io.Terminal.println("  • WAL-based durability", .{});
    io.Terminal.println("  • Static memory pools", .{});
    io.Terminal.println("", .{});
    io.Terminal.println("Version: 0.0.1 (Beta) - Custom I/O Implementation", .{});
}
