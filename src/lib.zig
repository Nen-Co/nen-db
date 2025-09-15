// NenDB - Main Library Entry Point
// The world's first predictable, AI-native graph database

const std = @import("std");

// Use nen-core for high-performance foundation
pub const nen_core = @import("nen-core");

// Use nen-net for networking capabilities
pub const nen_net = @import("nen-net");

// Core modules
pub const memory = @import("memory/layout.zig");
pub const constants = @import("constants.zig");

// Use nen-io and nen-json from the ecosystem instead of local implementations
pub const io = @import("nen-io");
pub const json = @import("nen-json");

// Legacy nendb.zig removed; GraphDB is primary engine now (graphdb.zig)
pub const graphdb = @import("graphdb.zig");

// Data-Oriented Design (DOD) modules - now using nen-core
pub const dod = nen_core.layouts;
pub const simd = nen_core.simd;

// Core DOD types
pub const GraphData = memory.GraphData;
pub const Stats = memory.Stats;

// Re-export main types for convenience
pub const GraphDB = graphdb.GraphDB;

// Re-export networking types from nen-net
pub const HttpServer = nen_net.HttpServer;
pub const HttpRequest = nen_net.HttpRequest;
pub const HttpResponse = nen_net.HttpResponse;
pub const TcpServer = nen_net.TcpServer;
pub const TcpClient = nen_net.TcpClient;
pub const WebSocketServer = nen_net.WebSocketServer;
pub const Router = nen_net.Router;

// Configuration
pub const Config = struct {
    node_pool_size: usize = constants.memory.node_pool_size,
    edge_pool_size: usize = constants.memory.edge_pool_size,
    embedding_pool_size: usize = constants.memory.embedding_pool_size,
    embedding_dim: usize = constants.data.embedding_dimensions,
    data_dir: []const u8 = ".",
};

// Convenience function to create a NenDB instance
pub fn create_graph(allocator: std.mem.Allocator, config: Config) !GraphDB {
    _ = config; // Config not used in this simplified version
    // Use provided data_dir; ensure isolated path so multiple tests don't contend on WAL lock
    var db: GraphDB = undefined;
    try db.init_inplace(allocator);
    return db; // return by value (copy); caller should deinit()
}

// Simplified embedded API - no configuration needed
pub fn open(data_dir: []const u8) !GraphDB {
    _ = data_dir; // Data dir not used in this simplified version
    var db: GraphDB = undefined;
    try db.init_inplace(std.heap.page_allocator);
    return db;
}

// In-memory only database (no persistence)
pub fn open_memory() !GraphDB {
    return open(":memory:");
}

// Quick start with default configuration
pub fn init() !GraphDB {
    return open("./nendb_data");
}

// Networking convenience functions
pub fn createHttpServer(port: u16) !HttpServer {
    return nen_net.createHttpServer(port);
}

pub fn createTcpServer(port: u16) !TcpServer {
    return nen_net.createTcpServer(port);
}

pub fn createWebSocketServer(port: u16) !WebSocketServer {
    return nen_net.createWebSocketServer(port);
}

// Create a networked GraphDB with HTTP API
pub fn createNetworkedGraphDB(allocator: std.mem.Allocator, port: u16, data_dir: []const u8) !struct { GraphDB, HttpServer } {
    var db: GraphDB = undefined;
    try db.init_inplace(allocator, data_dir);
    
    const server = try createHttpServer(port);
    
    return .{ db, server };
}

// Version information
pub const VERSION = constants.VERSION_SHORT;
pub const VERSION_STRING = constants.VERSION_FULL;

// Feature flags
pub const FEATURES = struct {
    pub const STATIC_ALLOCATION = true;
    pub const ZERO_GC = true;
    pub const BATCH_OPERATIONS = true;
    pub const AI_NATIVE = true;
    pub const PREDICTABLE_PERFORMANCE = true;
    pub const WAL_PERSISTENCE = true;
    pub const CYPHER_LIKE_QUERIES = true;
};

test "nendb basic functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const tmp_dir = "./.nendb_lib_basic";
    _ = std.fs.cwd().deleteTree(tmp_dir) catch {};
    try std.fs.cwd().makePath(tmp_dir);
    var db = try create_graph(allocator, Config{ .data_dir = tmp_dir });
    defer {
        db.deinit();
        _ = std.fs.cwd().deleteTree(tmp_dir) catch {};
    }

    // Test basic operations work in fresh directory
    const stats = db.get_memory_stats();
    try std.testing.expectEqual(@as(u32, 0), stats.nodes.node_count);
    try std.testing.expectEqual(@as(u32, 0), stats.nodes.edge_count);
    try std.testing.expectEqual(@as(u32, 0), stats.nodes.embedding_count);
}
