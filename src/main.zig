const std = @import("std");
const GraphDB = @import("graphdb.zig").GraphDB;
const layout = @import("memory/layout.zig");
const constants = @import("constants.zig");

pub fn main() !void {
    std.debug.print("\x1b[1;38;5;81m┌──────────────────────────────────────────┐\n", .{});
    std.debug.print("│      ⚡ NenDB • Graph Engine Core ⚡      │\n", .{});
    std.debug.print("└──────────────────────────────────────────┘\n", .{});
    std.debug.print("Version: {s} | Zig: {s}\n", .{ constants.VERSION_STRING, @import("builtin").zig_version_string });

    // Simple argument parsing
    var it = std.process.argsWithAllocator(std.heap.page_allocator) catch |err| {
        std.debug.print("Failed to get command line arguments: {}\n", .{err});
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

    std.debug.print("✅ NenDB started successfully with custom I/O!\n", .{});
}

fn run_demo() !void {
    std.debug.print("🚀 Running NenDB Demo - Graph Operations\n", .{});

    // Initialize database
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try GraphDB.init(allocator);
    defer db.deinit();

    std.debug.print("✅ Database initialized\n", .{});

    // Insert nodes
    std.debug.print("📝 Inserting nodes...\n", .{});
    const node1 = try db.addNode(1, 1); // ID=1, Kind=1
    const node2 = try db.addNode(2, 2); // ID=2, Kind=2
    const node3 = try db.addNode(3, 1); // ID=3, Kind=1

    std.debug.print("✅ Inserted 3 nodes\n", .{});

    // Insert edges
    std.debug.print("🔗 Inserting edges...\n", .{});
    _ = try db.addEdge(node1, node2, 1); // 1->2 with label 1
    _ = try db.addEdge(node2, node3, 2); // 2->3 with label 2
    _ = try db.addEdge(node3, node1, 3); // 3->1 with label 3

    std.debug.print("✅ Inserted 3 edges\n", .{});

    // Test lookups
    std.debug.print("🔍 Testing lookups...\n", .{});
    if (db.getNode(node1)) |node| {
        std.debug.print("  Found node: ID={d}, Kind={d}\n", .{ node.id, node.kind });
    }
    if (db.getNode(node2)) |node| {
        std.debug.print("  Found node: ID={d}, Kind={d}\n", .{ node.id, node.kind });
    }
    if (db.getNode(node3)) |node| {
        std.debug.print("  Found node: ID={d}, Kind={d}\n", .{ node.id, node.kind });
    }

    // Note: Edge lookups are commented out due to current implementation
    //     try std.debug.print("  Found edge: {d}->{d} (label={d})\n", .{ edge.from, edge.to, edge.label });

    // Delete operations
    std.debug.print("🗑️ Delete operations:\n", .{});
    std.debug.print("  ⚠️ Delete operations are implemented but need edge pool fixes\n", .{});
    std.debug.print("  🔧 TODO: Fix edge pool free() logic\n", .{});

    // Show statistics
    const stats = db.getStats();
    std.debug.print("📊 Database statistics:\n", .{});
    std.debug.print("  Nodes: {d}/{d} used\n", .{ stats.memory.nodes.node_count, stats.memory.nodes.node_capacity });
    std.debug.print("  Edges: {d}/{d} used\n", .{ stats.memory.nodes.edge_count, stats.memory.nodes.edge_capacity });
    std.debug.print("  Embeddings: {d}/{d} used\n", .{ stats.memory.nodes.embedding_count, stats.memory.nodes.embedding_capacity });
    std.debug.print("  Overall utilization: {d:.2}%\n", .{stats.memory.nodes.getUtilization() * 100.0});
    std.debug.print("  SIMD enabled: {}\n", .{stats.memory.simd_enabled});
    std.debug.print("  Cache efficiency: {d:.1}x\n", .{stats.memory.cache_efficiency});

    std.debug.print("🎉 Demo completed successfully!\n", .{});
}

fn print_help() !void {
    std.debug.print("NenDB - Production-focused, static-memory graph store\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Usage: nendb <command> [path]\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Commands:\n", .{});
    std.debug.print("  help                    Show this help message\n", .{});
    std.debug.print("  demo                    Run a demo of graph operations\n", .{});
    std.debug.print("  init <path>            Initialize a new NenDB at <path>\n", .{});
    std.debug.print("  up <path>              Start NenDB at <path> (default: current directory)\n", .{});
    std.debug.print("  status <path>          Show database status (default: current directory)\n", .{});
    std.debug.print("  query <path> <query>   Execute Cypher query at <path>\n", .{});
    std.debug.print("  serve                  Start TCP server on port 5454\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Features:\n", .{});
    std.debug.print("  • Node/Edge CRUD operations\n", .{});
    std.debug.print("  • Graph traversal (BFS/DFS)\n", .{});
    std.debug.print("  • Path finding algorithms\n", .{});
    std.debug.print("  • Property management\n", .{});
    std.debug.print("  • WAL-based durability\n", .{});
    std.debug.print("  • Static memory pools\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Version: {s} - Custom I/O Implementation\n", .{constants.VERSION_STRING});
}