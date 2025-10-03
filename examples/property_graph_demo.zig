// Property Graph Model Demo - KuzuDB Feature Replication
// Demonstrates the property graph model with TigerBeetle patterns

const std = @import("std");
const nendb = @import("nendb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 Property Graph Model Demo - KuzuDB Feature Replication\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n\n", .{});

    // Initialize property graph database
    std.debug.print("📁 Initializing Property Graph Database...\n", .{});
    var graph = try nendb.PropertyGraph.init(allocator, "demo_graph", "/tmp/property_demo");
    defer graph.deinit();

    std.debug.print("✅ Database initialized successfully\n\n", .{});

    // Create Person node schema
    std.debug.print("📋 Creating Person node schema...\n", .{});
    const person_schema = nendb.NodeSchema{
        .name = "Person",
        .properties = &.{
            .{ .name = "name", .type = nendb.PropertyType.String, .required = true, .indexed = true },
            .{ .name = "age", .type = nendb.PropertyType.Integer, .required = false, .indexed = true },
            .{ .name = "email", .type = nendb.PropertyType.String, .required = true, .indexed = true },
            .{ .name = "salary", .type = nendb.PropertyType.Float, .required = false, .indexed = false },
        },
    };

    try graph.registerNodeSchema(person_schema);
    std.debug.print("✅ Person schema registered\n", .{});

    // Create KNOWS edge schema
    std.debug.print("📋 Creating KNOWS edge schema...\n", .{});
    const knows_schema = nendb.EdgeSchema{
        .name = "KNOWS",
        .properties = &.{
            .{ .name = "since", .type = nendb.PropertyType.Integer, .required = true, .indexed = true },
            .{ .name = "strength", .type = nendb.PropertyType.Float, .required = false, .indexed = false },
            .{ .name = "context", .type = nendb.PropertyType.String, .required = false, .indexed = false },
        },
    };

    try graph.registerEdgeSchema(knows_schema);
    std.debug.print("✅ KNOWS schema registered\n\n", .{});

    // Create nodes with properties
    std.debug.print("👥 Creating nodes with properties...\n", .{});

    const alice_properties = &.{
        .{ .name = "name", .value = .{ .String = "Alice Johnson" } },
        .{ .name = "age", .value = .{ .Integer = 30 } },
        .{ .name = "email", .value = .{ .String = "alice.johnson@example.com" } },
        .{ .name = "salary", .value = .{ .Float = 75000.0 } },
    };

    const bob_properties = &.{
        .{ .name = "name", .value = .{ .String = "Bob Smith" } },
        .{ .name = "age", .value = .{ .Integer = 28 } },
        .{ .name = "email", .value = .{ .String = "bob.smith@example.com" } },
        .{ .name = "salary", .value = .{ .Float = 68000.0 } },
    };

    const charlie_properties = &.{
        .{ .name = "name", .value = .{ .String = "Charlie Brown" } },
        .{ .name = "age", .value = .{ .Integer = 35 } },
        .{ .name = "email", .value = .{ .String = "charlie.brown@example.com" } },
        .{ .name = "salary", .value = .{ .Float = 82000.0 } },
    };

    const alice_id = try graph.createNode("Person", alice_properties);
    const bob_id = try graph.createNode("Person", bob_properties);
    const charlie_id = try graph.createNode("Person", charlie_properties);

    std.debug.print("✅ Created 3 nodes: Alice ({}), Bob ({}), Charlie ({})\n", .{ alice_id, bob_id, charlie_id });

    // Create edges with properties
    std.debug.print("🔗 Creating edges with properties...\n", .{});

    const alice_knows_bob_properties = &.{
        .{ .name = "since", .value = .{ .Integer = 2020 } },
        .{ .name = "strength", .value = .{ .Float = 0.8 } },
        .{ .name = "context", .value = .{ .String = "colleague" } },
    };

    const bob_knows_charlie_properties = &.{
        .{ .name = "since", .value = .{ .Integer = 2019 } },
        .{ .name = "strength", .value = .{ .Float = 0.6 } },
        .{ .name = "context", .value = .{ .String = "friend" } },
    };

    const charlie_knows_alice_properties = &.{
        .{ .name = "since", .value = .{ .Integer = 2021 } },
        .{ .name = "strength", .value = .{ .Float = 0.9 } },
        .{ .name = "context", .value = .{ .String = "mentor" } },
    };

    const edge1_id = try graph.createEdge("KNOWS", alice_id, bob_id, alice_knows_bob_properties);
    const edge2_id = try graph.createEdge("KNOWS", bob_id, charlie_id, bob_knows_charlie_properties);
    const edge3_id = try graph.createEdge("KNOWS", charlie_id, alice_id, charlie_knows_alice_properties);

    std.debug.print("✅ Created 3 edges: {} -> {} -> {} -> {}\n", .{ alice_id, bob_id, charlie_id, alice_id });

    // Demonstrate node retrieval and property access
    std.debug.print("\n🔍 Demonstrating node retrieval and property access...\n", .{});

    const alice_node = graph.getNode(alice_id);
    if (alice_node) |node| {
        std.debug.print("📄 Alice's properties:\n", .{});
        for (node.properties) |prop| {
            std.debug.print("  • {}: ", .{prop.name});
            switch (prop.value) {
                .String => |s| std.debug.print("\"{s}\"\n", .{s}),
                .Integer => |i| std.debug.print("{d}\n", .{i}),
                .Float => |f| std.debug.print("{d:.2}\n", .{f}),
                .Boolean => |b| std.debug.print("{}\n", .{b}),
                else => std.debug.print("<other>\n", .{}),
            }
        }
    }

    // Demonstrate edge retrieval and property access
    std.debug.print("\n🔍 Demonstrating edge retrieval and property access...\n", .{});

    const edge1 = graph.getEdge(edge1_id);
    if (edge1) |edge| {
        std.debug.print("📄 Alice -> Bob relationship properties:\n", .{});
        for (edge.properties) |prop| {
            std.debug.print("  • {}: ", .{prop.name});
            switch (prop.value) {
                .String => |s| std.debug.print("\"{s}\"\n", .{s}),
                .Integer => |i| std.debug.print("{d}\n", .{i}),
                .Float => |f| std.debug.print("{d:.2}\n", .{f}),
                .Boolean => |b| std.debug.print("{}\n", .{b}),
                else => std.debug.print("<other>\n", .{}),
            }
        }
    }

    // Demonstrate batch operations
    std.debug.print("\n⚡ Demonstrating batch operations with SIMD optimization...\n", .{});

    const batch_size = 100;
    var batch_node_ids: [batch_size]u64 = undefined;

    // Create batch of nodes using SIMD optimization
    try graph.createNodesBatch("Person", batch_size, &batch_node_ids, struct {
        fn getProperties(index: usize, schema_name: []const u8) ![]const nendb.Property {
            _ = schema_name;
            const name = std.fmt.allocPrint(std.heap.page_allocator, "Person_{d}", .{index}) catch "Person";
            const email = std.fmt.allocPrint(std.heap.page_allocator, "person{d}@example.com", .{index}) catch "person@example.com";

            return &.{
                .{ .name = "name", .value = .{ .String = name } },
                .{ .name = "age", .value = .{ .Integer = @as(i64, @intCast(20 + (index % 50))) } },
                .{ .name = "email", .value = .{ .String = email } },
                .{ .name = "salary", .value = .{ .Float = @as(f64, @floatFromInt(50000 + (index % 50000))) } },
            };
        }
    }.getProperties);

    std.debug.print("✅ Created {} nodes in batch with SIMD optimization\n", .{batch_size});

    // Show final statistics
    std.debug.print("\n📊 Final Database Statistics:\n", .{});
    const stats = graph.getStats();
    std.debug.print("  • Total nodes: {d}\n", .{stats.node_count});
    std.debug.print("  • Total edges: {d}\n", .{stats.edge_count});
    std.debug.print("  • Total properties: {d}\n", .{stats.property_count});
    std.debug.print("  • Total schemas: {d}\n", .{stats.schema_count});

    // Show memory statistics
    std.debug.print("\n💾 Memory Statistics (TigerBeetle patterns):\n", .{});
    const mem_stats = graph.getMemoryStats();
    std.debug.print("  • Uses static allocation: {}\n", .{mem_stats.uses_static_allocation});
    std.debug.print("  • Dynamic allocations: {d}\n", .{mem_stats.dynamic_allocations});
    std.debug.print("  • Memory efficiency: {d:.2}%\n", .{mem_stats.memory_efficiency * 100.0});
    std.debug.print("  • Property pool usage: {d:.2}%\n", .{mem_stats.property_pool_usage * 100.0});
    std.debug.print("  • Node pool usage: {d:.2}%\n", .{mem_stats.node_pool_usage * 100.0});
    std.debug.print("  • Edge pool usage: {d:.2}%\n", .{mem_stats.edge_pool_usage * 100.0});

    std.debug.print("\n🎉 Property Graph Model Demo completed successfully!\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("✨ Features demonstrated:\n", .{});
    std.debug.print("  • Property graph model with typed properties\n", .{});
    std.debug.print("  • Schema validation and registration\n", .{});
    std.debug.print("  • Static memory allocation (TigerBeetle pattern)\n", .{});
    std.debug.print("  • Batch processing with SIMD optimization\n", .{});
    std.debug.print("  • WAL-based persistence\n", .{});
    std.debug.print("  • Memory efficiency monitoring\n", .{});
    std.debug.print("  • KuzuDB-compatible property model\n", .{});
}
