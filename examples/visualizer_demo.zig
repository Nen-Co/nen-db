// NenDB Graph Visualizer Demo
// Demonstrates the graph visualizer with sample data

const std = @import("std");
const nendb = @import("nendb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🎨 NenDB Graph Visualizer Demo\n", .{});
    std.debug.print("===============================\n", .{});
    std.debug.print("This demo creates sample graph data and starts the HTTP server\n", .{});
    std.debug.print("with the built-in graph visualizer.\n\n", .{});

    // Initialize database
    var db = nendb.Database.init(allocator, "visualizer_demo", "demo_data") catch |err| {
        std.debug.print("❌ Failed to initialize database: {}\n", .{err});
        return;
    };
    defer db.deinit();

    std.debug.print("✅ Database initialized\n", .{});

    // Create sample graph data
    try createSampleGraph(&db);

    // Show final stats
    const stats = db.get_stats();
    std.debug.print("📊 Sample graph created:\n", .{});
    std.debug.print("  • Nodes: {d}\n", .{stats.memory.nodes.node_count});
    std.debug.print("  • Edges: {d}\n", .{stats.memory.nodes.edge_count});
    std.debug.print("  • Utilization: {d:.2}%\n\n", .{stats.memory.nodes.getUtilization() * 100.0});

    std.debug.print("🌐 Starting HTTP server with visualizer...\n", .{});
    std.debug.print("  • Open http://localhost:8080/visualizer in your browser\n", .{});
    std.debug.print("  • Press Ctrl+C to stop the server\n\n", .{});

    // Start the HTTP server (this will run indefinitely)
    try startVisualizerServer(allocator, &db);
}

fn createSampleGraph(db: *nendb.Database) !void {
    std.debug.print("📝 Creating sample graph data...\n", .{});

    // Create nodes representing a social network
    const users = [_]struct { id: u64, name: []const u8 }{
        .{ .id = 1, .name = "Alice" },
        .{ .id = 2, .name = "Bob" },
        .{ .id = 3, .name = "Charlie" },
        .{ .id = 4, .name = "Diana" },
        .{ .id = 5, .name = "Eve" },
        .{ .id = 6, .name = "Frank" },
        .{ .id = 7, .name = "Grace" },
        .{ .id = 8, .name = "Henry" },
    };

    const products = [_]struct { id: u64, name: []const u8 }{
        .{ .id = 101, .name = "Laptop" },
        .{ .id = 102, .name = "Phone" },
        .{ .id = 103, .name = "Book" },
        .{ .id = 104, .name = "Coffee" },
    };

    const companies = [_]struct { id: u64, name: []const u8 }{
        .{ .id = 201, .name = "TechCorp" },
        .{ .id = 202, .name = "StartupXYZ" },
        .{ .id = 203, .name = "InnovationLab" },
    };

    // Add user nodes (kind = 1)
    for (users) |user| {
        try db.insert_node(user.id, 1);
        std.debug.print("  • Added user: {s} (ID: {d})\n", .{ user.name, user.id });
    }

    // Add product nodes (kind = 2)
    for (products) |product| {
        try db.insert_node(product.id, 2);
        std.debug.print("  • Added product: {s} (ID: {d})\n", .{ product.name, product.id });
    }

    // Add company nodes (kind = 3)
    for (companies) |company| {
        try db.insert_node(company.id, 3);
        std.debug.print("  • Added company: {s} (ID: {d})\n", .{ company.name, company.id });
    }

    // Create relationships (edges)
    const relationships = [_]struct { from: u64, to: u64, label: u32 }{
        // Social connections (label = 1: "friends_with")
        .{ .from = 1, .to = 2, .label = 1 }, // Alice -> Bob
        .{ .from = 1, .to = 3, .label = 1 }, // Alice -> Charlie
        .{ .from = 2, .to = 4, .label = 1 }, // Bob -> Diana
        .{ .from = 3, .to = 5, .label = 1 }, // Charlie -> Eve
        .{ .from = 4, .to = 6, .label = 1 }, // Diana -> Frank
        .{ .from = 5, .to = 7, .label = 1 }, // Eve -> Grace
        .{ .from = 6, .to = 8, .label = 1 }, // Frank -> Henry
        .{ .from = 7, .to = 1, .label = 1 }, // Grace -> Alice

        // Purchase relationships (label = 2: "purchased")
        .{ .from = 1, .to = 101, .label = 2 }, // Alice -> Laptop
        .{ .from = 2, .to = 102, .label = 2 }, // Bob -> Phone
        .{ .from = 3, .to = 103, .label = 2 }, // Charlie -> Book
        .{ .from = 4, .to = 104, .label = 2 }, // Diana -> Coffee
        .{ .from = 5, .to = 101, .label = 2 }, // Eve -> Laptop
        .{ .from = 6, .to = 102, .label = 2 }, // Frank -> Phone

        // Employment relationships (label = 3: "works_at")
        .{ .from = 1, .to = 201, .label = 3 }, // Alice -> TechCorp
        .{ .from = 2, .to = 202, .label = 3 }, // Bob -> StartupXYZ
        .{ .from = 3, .to = 203, .label = 3 }, // Charlie -> InnovationLab
        .{ .from = 4, .to = 201, .label = 3 }, // Diana -> TechCorp
        .{ .from = 5, .to = 202, .label = 3 }, // Eve -> StartupXYZ

        // Company relationships (label = 4: "partners_with")
        .{ .from = 201, .to = 202, .label = 4 }, // TechCorp -> StartupXYZ
        .{ .from = 202, .to = 203, .label = 4 }, // StartupXYZ -> InnovationLab
    };

    // Add edges
    for (relationships) |rel| {
        try db.insert_edge(rel.from, rel.to, rel.label);
    }

    std.debug.print("  • Added {d} relationships\n", .{relationships.len});
    std.debug.print("✅ Sample graph created successfully!\n\n", .{});
}

fn startVisualizerServer(allocator: std.mem.Allocator, db: *nendb.Database) !void {
    // This is a simplified version of the server startup
    // In a real implementation, you would call the actual server function
    // For now, we'll just show the instructions

    std.debug.print("🚀 To start the visualizer server, run:\n", .{});
    std.debug.print("   zig build && ./zig-out/bin/nendb serve\n\n", .{});
    std.debug.print("Then open http://localhost:8080/visualizer in your browser\n", .{});
}
