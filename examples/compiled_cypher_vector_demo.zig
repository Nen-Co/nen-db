// NenDB Compiled Cypher + Vector Demo
// Demonstrates compiled Cypher queries with native vector similarity search

const std = @import("std");
const nendb = @import("../src/lib.zig");

pub fn main() !void {
    std.debug.print("🚀 NenDB Compiled Cypher + Vector Demo\n", .{});

    // Initialize database with allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db: nendb.GraphDB = undefined;
    try db.init_inplace(allocator);
    defer db.deinit();

    // Step 1: Create sample data with embeddings
    try createSampleData(&db);

    // Step 2: Demonstrate vector similarity search
    try demonstrateVectorSearch(&db);

    // Step 3: Demonstrate compiled Cypher queries
    try demonstrateCompiledCypher(&db);

    // Step 4: Demonstrate hybrid queries
    try demonstrateHybridQueries(&db);

    std.debug.print("✅ Demo completed successfully!\n", .{});
}

fn createSampleData(db: *nendb.GraphDB) !void {
    std.debug.print("\n📊 Creating sample data with embeddings...\n", .{});

    // Create users with embeddings
    const users = [_]struct { id: u64, name: []const u8, embedding: [256]f32 }{
        .{ .id = 1, .name = "Alice", .embedding = generateEmbedding("software engineer") },
        .{ .id = 2, .name = "Bob", .embedding = generateEmbedding("data scientist") },
        .{ .id = 3, .name = "Charlie", .embedding = generateEmbedding("product manager") },
        .{ .id = 4, .name = "Diana", .embedding = generateEmbedding("designer") },
        .{ .id = 5, .name = "Eve", .embedding = generateEmbedding("software engineer") },
    };

    for (users) |user| {
        // Create node
        const node = nendb.pool.Node{
            .id = user.id,
            .kind = 1, // User type
            .reserved = [_]u8{0} ** 7,
            .props = [_]u8{0} ** nendb.constants.data.node_props_size,
        };
        try db.insert_node(node);

        // Set embedding
        try db.setNodeEmbedding(user.id, user.embedding);

        std.debug.print("  Created user: {s} (ID: {d})\n", .{ user.name, user.id });
    }

    // Create relationships
    const relationships = [_]struct { from: u64, to: u64, label: u16 }{
        .{ .from = 1, .to = 2, .label = 1 }, // Alice -> Bob (FRIENDS_WITH)
        .{ .from = 1, .to = 3, .label = 1 }, // Alice -> Charlie (FRIENDS_WITH)
        .{ .from = 2, .to = 4, .label = 1 }, // Bob -> Diana (FRIENDS_WITH)
        .{ .from = 3, .to = 5, .label = 1 }, // Charlie -> Eve (FRIENDS_WITH)
    };

    for (relationships) |rel| {
        const edge = nendb.pool.Edge{
            .from = rel.from,
            .to = rel.to,
            .label = rel.label,
            .reserved = [_]u8{0} ** 6,
            .props = [_]u8{0} ** nendb.constants.data.edge_props_size,
        };
        try db.insert_edge(edge);
    }

    std.debug.print("  Created {d} relationships\n", .{relationships.len});
}

fn demonstrateVectorSearch(db: *nendb.GraphDB) !void {
    std.debug.print("\n🔍 Demonstrating vector similarity search...\n", .{});

    // Query vector for "software engineer"
    const query_vector = generateEmbedding("software engineer");

    // Find similar nodes
    const similar_nodes = try db.findSimilarNodes(query_vector, 0.7, 5);
    defer db.allocator.free(similar_nodes);

    std.debug.print("  Found {d} similar nodes:\n", .{similar_nodes.len});
    for (similar_nodes, 0..) |node, i| {
        const embedding = db.getNodeEmbedding(node.id) orelse continue;
        const similarity = db.calculateCosineSimilarity(query_vector, embedding.vector);
        std.debug.print("    {d}. Node {d} (similarity: {d:.3})\n", .{ i + 1, node.id, similarity });
    }
}

fn demonstrateCompiledCypher(db: *nendb.GraphDB) !void {
    std.debug.print("\n⚡ Demonstrating compiled Cypher queries...\n", .{});

    // Example Cypher query with vector similarity
    const query =
        \\MATCH (n:User)-[:FRIENDS_WITH]->(friend:User)
        \\WHERE vector_similarity(n.embedding, $query_vector) > 0.8
        \\RETURN friend.name, vector_similarity(n.embedding, $query_vector) as similarity
        \\ORDER BY similarity DESC
        \\LIMIT 5
    ;

    const params = nendb.query.compiler.QueryParams{
        .query_vector = generateEmbedding("software engineer"),
        .similarity_threshold = 0.8,
        .limit = 5,
    };

    const result = try db.executeCompiledQuery(query, params);
    defer result.deinit();

    std.debug.print("  Compiled query returned {d} results:\n", .{result.rows.items.len});
    for (result.rows.items, 0..) |row, i| {
        std.debug.print("    {d}. Row {d}\n", .{ i + 1, i });
    }
}

fn demonstrateHybridQueries(db: *nendb.GraphDB) !void {
    std.debug.print("\n🔄 Demonstrating hybrid queries (vector + graph)...\n", .{});

    const query_vector = generateEmbedding("software engineer");
    const graph_pattern = "(n)-[:FRIENDS_WITH]->(friend)";
    const threshold: f32 = 0.7;
    const limit: usize = 3;

    const result = try db.hybridQuery(query_vector, graph_pattern, threshold, limit);
    defer result.deinit();

    std.debug.print("  Hybrid query returned {d} results:\n", .{result.rows.items.len});
    for (result.rows.items, 0..) |row, i| {
        std.debug.print("    {d}. Row {d}\n", .{ i + 1, i });
    }
}

// Generate a simple embedding based on text (for demo purposes)
fn generateEmbedding(text: []const u8) [256]f32 {
    var embedding: [256]f32 = undefined;

    // Simple hash-based embedding generation
    var hash: u32 = 0;
    for (text) |byte| {
        hash = hash *% 31 +% byte;
    }

    for (0..256) |i| {
        const seed = hash +% @as(u32, @intCast(i));
        const random_val = @as(f32, @floatFromInt(seed % 1000)) / 1000.0;
        embedding[i] = random_val;
    }

    return embedding;
}
