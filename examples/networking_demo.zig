const std = @import("std");
const nendb = @import("nendb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🌐 NenDB Networking Integration Demo\n", .{});
    std.debug.print("=====================================\n\n", .{});

    // Test that we can access nen-net types through nendb
    std.debug.print("✅ Available networking types:\n", .{});
    std.debug.print("  - HttpServer: {s}\n", .{@typeName(nendb.HttpServer)});
    std.debug.print("  - TcpServer: {s}\n", .{@typeName(nendb.TcpServer)});
    std.debug.print("  - WebSocketServer: {s}\n", .{@typeName(nendb.WebSocketServer)});
    std.debug.print("  - Router: {s}\n", .{@typeName(nendb.Router)});

    // Test that we can access nen-core types through nendb
    std.debug.print("\n✅ Available nen-core types:\n", .{});
    std.debug.print("  - NenError: {s}\n", .{@typeName(nendb.nen_core.NenError)});
    std.debug.print("  - MessageType: {s}\n", .{@typeName(nendb.nen_core.MessageType)});
    std.debug.print("  - BatchResult: {s}\n", .{@typeName(nendb.nen_core.BatchResult)});

    // Test creating a GraphDB
    std.debug.print("\n🗄️  Creating GraphDB...\n", .{});
    var db: nendb.GraphDB = undefined;
    try db.init_inplace(allocator, "./networking-demo-db");
    defer db.deinit();

    // Test creating networking servers
    std.debug.print("🌐 Testing networking server creation...\n", .{});
    
    // Test HTTP server creation
    _ = try nendb.createHttpServer(8080);
    std.debug.print("  ✅ HTTP Server created on port 8080\n", .{});
    
    // Test TCP server creation
    _ = try nendb.createTcpServer(8081);
    std.debug.print("  ✅ TCP Server created on port 8081\n", .{});
    
    // Test WebSocket server creation
    _ = try nendb.createWebSocketServer(8082);
    std.debug.print("  ✅ WebSocket Server created on port 8082\n", .{});

    // Test the networked GraphDB function
    std.debug.print("\n🔗 Testing networked GraphDB creation...\n", .{});
    _ = try nendb.createNetworkedGraphDB(allocator, 8083, "./networked-db");
    std.debug.print("  ✅ Networked GraphDB created with HTTP server on port 8083\n", .{});
    
    // Insert some test data
    std.debug.print("\n📊 Inserting test data...\n", .{});
    try db.insert_node(1, 1); // Node 1, type 1
    try db.insert_node(2, 2); // Node 2, type 2
    try db.insert_edge(1, 2, 1); // Edge from 1 to 2, type 1
    
    // Get database stats
    const stats = db.get_stats();
    std.debug.print("  ✅ Database stats: {d} nodes, {d} edges\n", .{ stats.memory.nodes.node_count, stats.memory.nodes.edge_count });

    std.debug.print("\n🎉 NenDB networking integration successful!\n", .{});
    std.debug.print("   - GraphDB with persistence: ✅\n", .{});
    std.debug.print("   - HTTP server creation: ✅\n", .{});
    std.debug.print("   - TCP server creation: ✅\n", .{});
    std.debug.print("   - WebSocket server creation: ✅\n", .{});
    std.debug.print("   - Networked GraphDB: ✅\n", .{});
    std.debug.print("   - nen-core integration: ✅\n", .{});
    std.debug.print("   - nen-net integration: ✅\n", .{});
}
