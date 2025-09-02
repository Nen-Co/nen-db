// NenDB Enhanced Networking Demo
// Demonstrates the high-performance networking APIs using nen-net

const std = @import("std");
const api = @import("nendb").api;

pub fn main() !void {
    std.debug.print("🚀 NenDB Enhanced Networking Demo\n", .{});
    std.debug.print("==================================\n\n", .{});

    // Start the enhanced server in a separate thread
    std.debug.print("📡 Starting enhanced server...\n", .{});
    const server_thread = try std.Thread.spawn(.{}, runServer, .{});
    defer server_thread.join();

    // Give the server time to start
    std.time.sleep(100 * std.time.ns_per_ms);

    // Create and test the client
    std.debug.print("🔌 Testing client connection...\n", .{});
    try testClient();

    std.debug.print("\n✅ Demo completed successfully!\n", .{});
}

fn runServer() void {
    // Start the server on port 8081
    api.server.startDefaultServer(8081) catch |err| {
        std.debug.print("⚠️  Server error: {any}\n", .{err});
    };
}

fn testClient() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create client configuration
    const config = api.client.ClientConfig{
        .host = "localhost",
        .port = 8081,
        .timeout_ms = 5000,
        .buffer_size = 8192,
        .connection_pool_size = 5,
    };

    // Initialize client
    var client = try api.client.Client.init(allocator, config);
    defer client.deinit();

    // Connect to server
    try client.connect();
    std.debug.print("✅ Client connected to server\n", .{});

    // Test basic operations
    try testBasicOperations(&client);

    // Test graph operations
    try testGraphOperations(&client);

    // Test document operations
    try testDocumentOperations(&client);

    // Test key-value operations
    try testKeyValueOperations(&client);

    // Disconnect
    client.disconnect();
    std.debug.print("✅ Client disconnected from server\n", .{});
}

fn testBasicOperations(client: *api.client.Client) !void {
    std.debug.print("\n📊 Testing basic operations...\n", .{});

    // Test ping
    const ping_response = try client.ping();
    std.debug.print("PING: {any}\n", .{ping_response.data});

    // Test status
    const status_response = try client.status();
    std.debug.print("STATUS: {any}\n", .{status_response.data});
}

fn testGraphOperations(client: *api.client.Client) !void {
    std.debug.print("\n🕸️  Testing graph operations...\n", .{});

    // Create properties for a node
    var properties = std.StringHashMap([]const u8).init(std.heap.page_allocator);
    defer properties.deinit();
    try properties.put("name", "Alice");
    try properties.put("age", "30");

    // Test node insertion
    const labels = [_][]const u8{ "Person", "User" };
    const node_response = try client.insertNode("alice_001", &labels, properties);
    std.debug.print("Insert Node: {any}\n", .{node_response.data});

    // Test edge insertion
    var edge_properties = std.StringHashMap([]const u8).init(std.heap.page_allocator);
    defer edge_properties.deinit();
    try edge_properties.put("since", "2024");

    const edge_response = try client.insertEdge("alice_001", "bob_001", "KNOWS", edge_properties);
    std.debug.print("Insert Edge: {any}\n", .{edge_response.data});

    // Test query
    var query_params = std.StringHashMap([]const u8).init(std.heap.page_allocator);
    defer query_params.deinit();
    try query_params.put("name", "Alice");

    const query_response = try client.query("MATCH (n:Person {name: $name}) RETURN n", query_params);
    std.debug.print("Query: {any}\n", .{query_response.data});
}

fn testDocumentOperations(client: *api.client.Client) !void {
    std.debug.print("\n📄 Testing document operations...\n", .{});

    // Test document insertion
    const document = "{\"name\":\"John Doe\",\"email\":\"john@example.com\",\"age\":25}";
    const insert_response = try client.insertDocument("users", document);
    std.debug.print("Insert Document: {any}\n", .{insert_response.data});

    // Test document find
    const query = "{\"name\":\"John Doe\"}";
    const find_response = try client.findDocument("users", query);
    std.debug.print("Find Document: {any}\n", .{find_response.data});

    // Test document update
    const updates = "{\"age\":26,\"last_updated\":\"2024-01-01\"}";
    const update_response = try client.updateDocument("users", "john_001", updates);
    std.debug.print("Update Document: {any}\n", .{update_response.data});

    // Test document deletion
    const delete_response = try client.deleteDocument("users", "john_001");
    std.debug.print("Delete Document: {any}\n", .{delete_response.data});
}

fn testKeyValueOperations(client: *api.client.Client) !void {
    std.debug.print("\n🔑 Testing key-value operations...\n", .{});

    // Test set operation
    const set_response = try client.set("user:alice", "{\"name\":\"Alice\",\"active\":true}", 3600);
    std.debug.print("SET: {any}\n", .{set_response.data});

    // Test get operation
    const get_response = try client.get("user:alice");
    std.debug.print("GET: {any}\n", .{get_response.data});

    // Test set with TTL
    const set_ttl_response = try client.set("temp:session", "session_data", 60);
    std.debug.print("SET with TTL: {any}\n", .{set_ttl_response.data});

    // Test delete operation
    const delete_response = try client.delete("user:alice");
    std.debug.print("DELETE: {any}\n", .{delete_response.data});
}

// Test the enhanced server directly
test "enhanced server basic functionality" {
    const gpa = std.testing.allocator;

    // Create server configuration
    const config = api.server.ServerConfig{
        .port = 0, // Use random port for testing
        .max_connections = 10,
        .buffer_size = 1024,
    };

    // Initialize server
    var server = try api.server.EnhancedServer.init(gpa, config);
    defer server.deinit();

    // Test server initialization
    try std.testing.expect(!server.is_running);
    try std.testing.expect(server.connections.items.len == 0);
}

test "enhanced client basic functionality" {
    const gpa = std.testing.allocator;

    // Create client configuration
    const config = api.client.ClientConfig{
        .host = "localhost",
        .port = 9999, // Use non-existent port for testing
        .connection_pool_size = 5,
    };

    // Initialize client
    var client = try api.client.Client.init(gpa, config);
    defer client.deinit();

    // Test client initialization
    try std.testing.expect(!client.is_connected);
    try std.testing.expect(client.connections.items.len == 0);
}
