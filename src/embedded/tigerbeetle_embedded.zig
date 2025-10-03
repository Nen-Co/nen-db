// NenDB TigerBeetle-Style Embedded Database
// KuzuDB-compatible embedded graph database with TigerBeetle patterns

const std = @import("std");
const assert = std.debug.assert;

// Import shared components
const shared = @import("shared");
const EmbeddedDB = shared.EmbeddedDB;
const EmbeddedConfig = shared.EmbeddedConfig;
const BatchConfig = shared.BatchConfig;

// =============================================================================
// Main Application
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 NenDB TigerBeetle-Style Embedded Database\n", .{});
    std.debug.print("==========================================\n", .{});

    // Initialize database with TigerBeetle-style configuration
    const config = EmbeddedConfig{
        .max_nodes = 1_000_000, // 1M nodes
        .max_edges = 10_000_000, // 10M edges
        .max_properties = 5_000_000, // 5M properties
        .max_vectors = 100_000, // 100K vectors
        .vector_dimensions = 256, // 256D embeddings

        .enable_simd = true,
        .enable_wal = true,
        .enable_batching = true,
        .enable_vector_search = true,

        .batch_config = BatchConfig{
            .max_batch_size = 8192,
            .batch_timeout_ms = 100,
            .auto_commit_threshold = 1000,
            .enable_zero_copy = true,
            .enable_atomic_commit = true,
            .enable_batch_statistics = true,
        },

        .data_dir = "tigerbeetle_data",
        .log_level = .info,
    };

    var db = try EmbeddedDB.init(allocator, config);
    defer db.deinit();

    // Run performance tests
    try runPerformanceTests(&db);

    // Run KuzuDB compatibility tests
    try runKuzuDBCompatibilityTests(&db);

    // Run vector search tests
    try runVectorSearchTests(&db);

    std.debug.print("\n✅ All tests completed successfully!\n", .{});
}

// =============================================================================
// Performance Tests (TigerBeetle Style)
// =============================================================================

fn runPerformanceTests(db: *EmbeddedDB) !void {
    std.debug.print("\n📊 Running Performance Tests...\n", .{});

    const test_start = std.time.nanoTimestamp();

    // Test 1: Batch node insertion (TigerBeetle style)
    try testBatchNodeInsertion(db);

    // Test 2: Batch edge insertion (TigerBeetle style)
    try testBatchEdgeInsertion(db);

    // Test 3: SIMD-optimized queries
    try testSIMDOptimizedQueries(db);

    // Test 4: Memory efficiency
    try testMemoryEfficiency(db);

    const test_duration = std.time.nanoTimestamp() - test_start;
    std.debug.print("⏱️  Total test duration: {d:.2}ms\n", .{@as(f64, @floatFromInt(test_duration)) / 1_000_000.0});
}

fn testBatchNodeInsertion(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing batch node insertion...\n", .{});

    const batch_size = 10000;
    var nodes: [10000]shared.embedded_db.NodeData = undefined;

    // Prepare batch data
    for (0..batch_size) |i| {
        nodes[i] = .{
            .id = @intCast(i + 1),
            .kind = @intCast((i % 10) + 1), // 10 different node types
        };
    }

    const start = std.time.nanoTimestamp();
    try db.addNodesBatch(&nodes);
    const duration = std.time.nanoTimestamp() - start;

    const nodes_per_second = (@as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0) / @as(f64, @floatFromInt(duration));

    std.debug.print("    ✅ Inserted {d} nodes in {d:.2}ms ({d:.0} nodes/sec)\n", .{
        batch_size,
        @as(f64, @floatFromInt(duration)) / 1_000_000.0,
        nodes_per_second,
    });
}

fn testBatchEdgeInsertion(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing batch edge insertion...\n", .{});

    const batch_size = 20000;
    var edges: [20000]shared.embedded_db.EdgeData = undefined;

    // Prepare batch data (create a connected graph)
    for (0..batch_size) |i| {
        const from = @as(u64, @intCast((i % 5000) + 1)); // Connect to first 5000 nodes
        const to = @as(u64, @intCast(((i + 1) % 5000) + 1));

        edges[i] = .{
            .from = from,
            .to = to,
            .label = @intCast((i % 5) + 1), // 5 different edge types
        };
    }

    const start = std.time.nanoTimestamp();
    try db.addEdgesBatch(&edges);
    const duration = std.time.nanoTimestamp() - start;

    const edges_per_second = (@as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0) / @as(f64, @floatFromInt(duration));

    std.debug.print("    ✅ Inserted {d} edges in {d:.2}ms ({d:.0} edges/sec)\n", .{
        batch_size,
        @as(f64, @floatFromInt(duration)) / 1_000_000.0,
        edges_per_second,
    });
}

fn testSIMDOptimizedQueries(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing SIMD-optimized queries...\n", .{});

    const query_count = 1000;
    var results: [100]u32 = undefined;

    const start = std.time.nanoTimestamp();

    for (0..query_count) |_| {
        // Test node filtering by kind
        const count = db.filterNodesByKind(1, &results);
        _ = count;

        // Test edge filtering by label
        const edge_count = db.filterEdgesByLabel(1, &results);
        _ = edge_count;
    }

    const duration = std.time.nanoTimestamp() - start;
    const queries_per_second = (@as(f64, @floatFromInt(query_count)) * 1_000_000_000.0) / @as(f64, @floatFromInt(duration));

    std.debug.print("    ✅ Executed {d} queries in {d:.2}ms ({d:.0} queries/sec)\n", .{
        query_count,
        @as(f64, @floatFromInt(duration)) / 1_000_000.0,
        queries_per_second,
    });
}

fn testMemoryEfficiency(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing memory efficiency...\n", .{});

    const stats = db.getStats();
    const batch_stats = db.getBatchStats();

    std.debug.print("    📊 Database Statistics:\n", .{});
    std.debug.print("      • Nodes: {d}\n", .{stats.nodes_count});
    std.debug.print("      • Edges: {d}\n", .{stats.edges_count});
    std.debug.print("      • Memory Utilization: {d:.2}%\n", .{stats.memory_utilization * 100.0});
    std.debug.print("      • Batches Committed: {d}\n", .{stats.batches_committed});
    std.debug.print("      • Average Batch Size: {d:.1}\n", .{batch_stats.getAverageBatchSize()});
}

// =============================================================================
// KuzuDB Compatibility Tests
// =============================================================================

fn runKuzuDBCompatibilityTests(db: *EmbeddedDB) !void {
    std.debug.print("\n🔍 Running KuzuDB Compatibility Tests...\n", .{});

    // Test 1: Property graph operations
    try testPropertyGraphOperations(db);

    // Test 2: Graph traversal
    try testGraphTraversal(db);

    // Test 3: Bulk loading
    try testBulkLoading(db);
}

fn testPropertyGraphOperations(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing property graph operations...\n", .{});

    // Add nodes with properties
    try db.addNode(1, "Person", "{\"name\":\"Alice\",\"age\":30}");
    try db.addNode(2, "Person", "{\"name\":\"Bob\",\"age\":25}");
    try db.addNode(3, "Company", "{\"name\":\"TechCorp\",\"founded\":2020}");

    // Add edges with properties
    try db.addEdge(1, 3, "WORKS_AT", "{\"position\":\"Engineer\",\"since\":2023}");
    try db.addEdge(2, 3, "WORKS_AT", "{\"position\":\"Designer\",\"since\":2022}");
    try db.addEdge(1, 2, "KNOWS", "{\"since\":2020}");

    // Force commit
    try db.flush();

    // Test queries
    const node = db.findNode(1);
    try std.testing.expect(node != null);
    try std.testing.expectEqual(@as(u64, 1), node.?.id);

    var outgoing: [10]u32 = undefined;
    const outgoing_count = db.findOutgoingEdges(1, &outgoing);
    try std.testing.expect(outgoing_count >= 2); // Should find WORKS_AT and KNOWS edges

    std.debug.print("    ✅ Property graph operations working\n", .{});
}

fn testGraphTraversal(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing graph traversal...\n", .{});

    // Create a small graph for traversal
    try db.addNode(100, "Person", null);
    try db.addNode(101, "Person", null);
    try db.addNode(102, "Person", null);
    try db.addNode(103, "Person", null);

    try db.addEdge(100, 101, "FRIEND", null);
    try db.addEdge(101, 102, "FRIEND", null);
    try db.addEdge(102, 103, "FRIEND", null);
    try db.addEdge(100, 103, "FRIEND", null);

    try db.flush();

    // Test outgoing edges
    var outgoing: [10]u32 = undefined;
    const outgoing_count = db.findOutgoingEdges(100, &outgoing);
    try std.testing.expect(outgoing_count >= 2);

    // Test incoming edges
    var incoming: [10]u32 = undefined;
    const incoming_count = db.findIncomingEdges(103, &incoming);
    try std.testing.expect(incoming_count >= 2);

    std.debug.print("    ✅ Graph traversal working\n", .{});
}

fn testBulkLoading(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing bulk loading...\n", .{});

    // Create large batch for bulk loading
    const bulk_size = 5000;
    var nodes: [5000]shared.embedded_db.NodeData = undefined;
    var edges: [5000]shared.embedded_db.EdgeData = undefined;

    // Prepare nodes
    for (0..bulk_size) |i| {
        nodes[i] = .{
            .id = @intCast(i + 1000),
            .kind = @intCast((i % 20) + 1),
        };
    }

    // Prepare edges
    for (0..bulk_size) |i| {
        const from = @as(u64, @intCast(1000 + (i % 1000)));
        const to = @as(u64, @intCast(1000 + ((i + 1) % 1000)));

        edges[i] = .{
            .from = from,
            .to = to,
            .label = @intCast((i % 10) + 1),
        };
    }

    const start = std.time.nanoTimestamp();

    // Bulk load nodes
    try db.addNodesBatch(&nodes);

    // Bulk load edges
    try db.addEdgesBatch(&edges);

    const duration = std.time.nanoTimestamp() - start;
    const items_per_second = (@as(f64, @floatFromInt(bulk_size * 2)) * 1_000_000_000.0) / @as(f64, @floatFromInt(duration));

    std.debug.print("    ✅ Bulk loaded {d} items in {d:.2}ms ({d:.0} items/sec)\n", .{
        bulk_size * 2,
        @as(f64, @floatFromInt(duration)) / 1_000_000.0,
        items_per_second,
    });
}

// =============================================================================
// Vector Search Tests
// =============================================================================

fn runVectorSearchTests(db: *EmbeddedDB) !void {
    std.debug.print("\n🔍 Running Vector Search Tests...\n", .{});

    // Test vector insertion and similarity search
    try testVectorOperations(db);

    // Test vector performance
    try testVectorPerformance(db);
}

fn testVectorOperations(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing vector operations...\n", .{});

    // Add some test vectors
    var vectors: [5][128]f32 = undefined;
    for (0..5) |i| {
        for (0..128) |j| {
            vectors[i][j] = @as(f32, @floatFromInt(i * 10 + j)) * 0.01;
        }
    }

    // Insert vectors for different nodes
    for (0..5) |i| {
        try db.addVector(@intCast(i + 2000), &vectors[i]);
    }

    try db.flush();

    // Test similarity search
    var query_vector: [128]f32 = undefined;
    for (0..128) |i| {
        query_vector[i] = @as(f32, @floatFromInt(i)) * 0.01; // Similar to vector 0
    }

    var results: [10]u64 = undefined;
    const result_count = db.findSimilarVectors(&query_vector, 3, &results);

    try std.testing.expect(result_count > 0);
    try std.testing.expectEqual(@as(u64, 2000), results[0]); // Should find node 2000 first

    std.debug.print("    ✅ Vector operations working (found {d} similar vectors)\n", .{result_count});
}

fn testVectorPerformance(db: *EmbeddedDB) !void {
    std.debug.print("  🔸 Testing vector performance...\n", .{});

    const vector_count = 1000;
    const search_count = 100;

    // Insert many vectors
    for (0..vector_count) |i| {
        var vector: [128]f32 = undefined;
        for (0..128) |j| {
            vector[j] = @as(f32, @floatFromInt(i * 128 + j)) * 0.001;
        }
        try db.addVector(@intCast(i + 3000), &vector);
    }

    try db.flush();

    // Test search performance
    var query_vector: [128]f32 = undefined;
    for (0..128) |i| {
        query_vector[i] = @as(f32, @floatFromInt(i)) * 0.001;
    }

    const start = std.time.nanoTimestamp();

    for (0..search_count) |_| {
        var results: [10]u64 = undefined;
        _ = db.findSimilarVectors(&query_vector, 5, &results);
    }

    const duration = std.time.nanoTimestamp() - start;
    const searches_per_second = (@as(f64, @floatFromInt(search_count)) * 1_000_000_000.0) / @as(f64, @floatFromInt(duration));

    std.debug.print("    ✅ Performed {d} searches in {d:.2}ms ({d:.0} searches/sec)\n", .{
        search_count,
        @as(f64, @floatFromInt(duration)) / 1_000_000.0,
        searches_per_second,
    });
}
