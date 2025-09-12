// NenDB CLI - Command Line Interface
// Simple CLI for interacting with NenDB

const std = @import("std");
const nendb = @import("lib.zig");
const io = nendb.io; // Use nen-io from the ecosystem
const GraphDB = @import("graphdb.zig").GraphDB;
const layout = @import("memory/layout.zig");
const constants = @import("constants.zig");

pub fn main() !void {
    try io.Terminal.println("\x1b[1;38;5;81m┌──────────────────────────────────────────┐", .{});
    try io.Terminal.println("│      ⚡ NenDB • Graph Engine Core ⚡      │", .{});
    try io.Terminal.println("└──────────────────────────────────────────┘", .{});
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

    try db.insert_node(1, 1);
    try db.insert_node(2, 1);
    try db.insert_node(3, 2);

    try io.Terminal.success("✅ Inserted 3 nodes", .{});

    // Insert edges
    try io.Terminal.infoln("🔗 Inserting edges...", .{});

    try db.insert_edge(1, 2, 1);
    try db.insert_edge(2, 3, 1);
    try db.insert_edge(1, 3, 2);
    try io.Terminal.success("✅ Inserted 3 edges", .{});

    // Lookup operations
    try io.Terminal.infoln("🔍 Testing lookups...", .{});

    const found_node_index = db.lookup_node(1);
    if (found_node_index) |index| {
        const node_id = db.graph_data.node_ids[index];
        const node_kind = db.graph_data.node_kinds[index];
        try io.Terminal.println("  Found node: ID={d}, Kind={d}", .{ node_id, node_kind });
    }

    // TODO: Update edge lookup for DOD (temporarily disabled)
    // const found_edge = db.lookup_edge(1, 2);
    // if (found_edge) |edge| {
    //     try io.Terminal.println("  Found edge: {d}->{d} (label={d})", .{ edge.from, edge.to, edge.label });
    // }

    // Delete operations (commented out for now)
    try io.Terminal.infoln("🗑️ Delete operations:", .{});
    try io.Terminal.println("  ⚠️ Delete operations are implemented but need edge pool fixes", .{});
    try io.Terminal.println("  🔧 TODO: Fix edge pool free() logic", .{});

    // Get statistics
    try io.Terminal.infoln("📊 Database statistics:", .{});
    const stats = db.get_stats();
    try io.Terminal.println("  Nodes: {d}/{d} used", .{ stats.memory.nodes.node_count, stats.memory.nodes.node_capacity });
    try io.Terminal.println("  Edges: {d}/{d} used", .{ stats.memory.nodes.edge_count, stats.memory.nodes.edge_capacity });
    try io.Terminal.println("  Embeddings: {d}/{d} used", .{ stats.memory.nodes.embedding_count, stats.memory.nodes.embedding_capacity });
    try io.Terminal.println("  Overall utilization: {d:.2}%", .{stats.memory.nodes.getUtilization() * 100.0});
    try io.Terminal.println("  SIMD enabled: {}", .{stats.memory.simd_enabled});
    try io.Terminal.println("  Cache efficiency: {d:.1}x", .{stats.memory.cache_efficiency});

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
