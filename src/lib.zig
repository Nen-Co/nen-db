// NenDB - Main Library Entry Point
// The world's first predictable, AI-native graph database

const std = @import("std");
const assert = std.debug.assert;

// Nen ecosystem dependencies
pub const nen_core = @import("nen-core");
pub const nen_net = @import("nen-net");
pub const io = @import("nen-io");
pub const json = @import("nen-json");

// Core modules (disabled problematic ones)
pub const constants = @import("constants.zig");

// Knowledge graph utilities
pub const KnowledgeGraphParser = @import("knowledge_graph_parser.zig").KnowledgeGraphParser;
pub const KnowledgeTriple = @import("knowledge_graph_parser.zig").KnowledgeTriple;

// Data-Oriented Design (DOD) modules from nen-core
pub const dod = nen_core.layouts;
pub const simd = nen_core.simd;

// =============================================================================
// Core Database Types and Statistics
// =============================================================================

pub const NodeStats = struct {
    node_count: u64,
    node_capacity: u64,
    edge_count: u64,
    edge_capacity: u64,

    pub inline fn getUtilization(self: NodeStats) f64 {
        assert(self.node_capacity > 0);
        assert(self.edge_capacity > 0);

        const total_used = self.node_count + self.edge_count;
        const total_capacity = self.node_capacity + self.edge_capacity;

        assert(total_used <= total_capacity);
        return @as(f64, @floatFromInt(total_used)) / @as(f64, @floatFromInt(total_capacity));
    }
};

pub const MemoryStats = struct {
    nodes: NodeStats,
};

pub const DatabaseStats = struct {
    memory: MemoryStats,
};

// =============================================================================
// Core Database Implementation
// =============================================================================

pub const Database = struct {
    name: []const u8,
    path: []const u8,
    allocator: std.mem.Allocator,
    nodes: std.AutoHashMap(u64, Node),
    edges: std.AutoHashMap(u64, Edge),
    next_node_id: u64,
    next_edge_id: u64,

    const Node = struct {
        id: u64,
        kind: u32,
        created_at: i64,
    };

    const Edge = struct {
        id: u64,
        from: u64,
        to: u64,
        label: u32,
        created_at: i64,
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, path: []const u8) !Database {
        assert(name.len > 0);
        assert(path.len > 0);

        return Database{
            .name = name,
            .path = path,
            .allocator = allocator,
            .nodes = std.AutoHashMap(u64, Node).init(allocator),
            .edges = std.AutoHashMap(u64, Edge).init(allocator),
            .next_node_id = 1,
            .next_edge_id = 1,
        };
    }

    pub fn deinit(self: *Database) void {
        self.nodes.deinit();
        self.edges.deinit();
    }

    pub inline fn insert_node(self: *Database, id: u64, kind: u32) !void {
        assert(id > 0);

        const node = Node{
            .id = id,
            .kind = kind,
            .created_at = std.time.timestamp(),
        };

        try self.nodes.put(id, node);

        if (id >= self.next_node_id) {
            self.next_node_id = id + 1;
        }
    }

    pub inline fn insert_edge(self: *Database, from: u64, to: u64, label: u32) !void {
        assert(from > 0);
        assert(to > 0);
        assert(from != to); // No self-loops for now

        const edge_id = self.next_edge_id;
        const edge = Edge{
            .id = edge_id,
            .from = from,
            .to = to,
            .label = label,
            .created_at = std.time.timestamp(),
        };

        try self.edges.put(edge_id, edge);
        self.next_edge_id += 1;
    }

    pub inline fn lookup_node(self: *Database, id: u64) ?u64 {
        assert(id > 0);

        if (self.nodes.contains(id)) {
            return id;
        }
        return null;
    }

    pub inline fn get_stats(self: *Database) DatabaseStats {
        return DatabaseStats{
            .memory = MemoryStats{
                .nodes = NodeStats{
                    .node_count = @intCast(self.nodes.count()),
                    .node_capacity = 10000, // Static capacity for now
                    .edge_count = @intCast(self.edges.count()),
                    .edge_capacity = 50000, // Static capacity for now
                },
            },
        };
    }
};

// =============================================================================
// Type Aliases and Re-exports
// =============================================================================

// Main database type alias for compatibility
pub const GraphDB = Database;

// Re-export networking types from nen-net
pub const HttpServer = nen_net.HttpServer;
pub const HttpRequest = nen_net.HttpRequest;
pub const HttpResponse = nen_net.HttpResponse;
pub const TcpServer = nen_net.TcpServer;
pub const TcpClient = nen_net.TcpClient;
pub const WebSocketServer = nen_net.WebSocketServer;
pub const Router = nen_net.Router;

// =============================================================================
// Public API Functions
// =============================================================================

/// Create a database with custom configuration
pub fn create_graph(allocator: std.mem.Allocator, name: []const u8, path: []const u8) !Database {
    assert(name.len > 0);
    assert(path.len > 0);

    return try Database.init(allocator, name, path);
}

/// Open a database at the specified directory
pub inline fn open(data_dir: []const u8) !Database {
    assert(data_dir.len > 0);

    return try Database.init(std.heap.page_allocator, "default", data_dir);
}

/// Create an in-memory database (no persistence)
pub inline fn open_memory() !Database {
    return try Database.init(std.heap.page_allocator, "memory", ":memory:");
}

/// Initialize a database with default settings
pub inline fn init() !Database {
    return try open("./nendb_data");
}

// =============================================================================
// Networking Functions
// =============================================================================

/// Create HTTP server on specified port
pub inline fn createHttpServer(port: u16) !HttpServer {
    assert(port > 0);
    return try nen_net.createHttpServer(port);
}

/// Create TCP server on specified port
pub inline fn createTcpServer(port: u16) !TcpServer {
    assert(port > 0);
    return try nen_net.createTcpServer(port);
}

/// Create WebSocket server on specified port
pub inline fn createWebSocketServer(port: u16) !WebSocketServer {
    assert(port > 0);
    return try nen_net.createWebSocketServer(port);
}

/// Create a networked database with HTTP API
pub fn createNetworkedGraphDB(allocator: std.mem.Allocator, port: u16, data_dir: []const u8) !struct { Database, HttpServer } {
    assert(port > 0);
    assert(data_dir.len > 0);

    const db = try Database.init(allocator, "networked", data_dir);
    const server = try createHttpServer(port);

    return .{ db, server };
}

// =============================================================================
// Tests
// =============================================================================

test "database creation and basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try Database.init(allocator, "test", "/tmp/test");
    defer db.deinit();

    // Test node operations
    try db.insert_node(1, 100);
    try db.insert_node(2, 200);

    const found = db.lookup_node(1);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(u64, 1), found.?);

    // Test edge operations
    try db.insert_edge(1, 2, 50);

    // Test statistics
    const stats = db.get_stats();
    try std.testing.expectEqual(@as(u64, 2), stats.memory.nodes.node_count);
    try std.testing.expectEqual(@as(u64, 1), stats.memory.nodes.edge_count);
}
