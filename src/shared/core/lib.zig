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

// Concurrency support
pub const concurrency = @import("concurrency.zig");

// WAL persistence support
const wal_mod = @import("memory/wal.zig");

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

    // Concurrency protection
    rwlock: concurrency.ReadWriteLock,
    seqlock: concurrency.Seqlock,
    node_id_generator: concurrency.AtomicIdGenerator,
    edge_id_generator: concurrency.AtomicIdGenerator,
    node_counter: concurrency.AtomicCounter,
    edge_counter: concurrency.AtomicCounter,

    // Performance monitoring
    metrics: concurrency.ConcurrencyMetrics,

    // Deadlock prevention
    deadlock_detector: concurrency.DeadlockDetector,

    // WAL persistence
    wal: ?wal_mod.Wal = null,
    wal_path: []const u8 = "",

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

        // Ensure directory exists before creating WAL
        std.fs.cwd().makeDir(path) catch |err| switch (err) {
            error.PathAlreadyExists => {}, // Directory already exists, that's fine
            else => return err,
        };

        // Create WAL path
        const wal_path = try std.fmt.allocPrint(allocator, "{s}/nendb.wal", .{path});

        // Initialize WAL (skip for memory databases)
        var wal: ?wal_mod.Wal = null;
        if (!std.mem.eql(u8, path, ":memory:")) {
            wal = try wal_mod.Wal.open(wal_path);
            std.debug.print("🔧 WAL created at: {s}\n", .{wal_path});
        }

        return Database{
            .name = name,
            .path = path,
            .allocator = allocator,
            .nodes = std.AutoHashMap(u64, Node).init(allocator),
            .edges = std.AutoHashMap(u64, Edge).init(allocator),

            // Initialize concurrency primitives
            .rwlock = concurrency.ReadWriteLock{},
            .seqlock = concurrency.Seqlock{},
            .node_id_generator = concurrency.AtomicIdGenerator{},
            .edge_id_generator = concurrency.AtomicIdGenerator{},
            .node_counter = concurrency.AtomicCounter{},
            .edge_counter = concurrency.AtomicCounter{},
            .metrics = concurrency.ConcurrencyMetrics{},
            .deadlock_detector = concurrency.DeadlockDetector.init(allocator),

            // WAL persistence
            .wal = wal,
            .wal_path = wal_path,
        };
    }

    pub fn deinit(self: *Database) void {
        self.nodes.deinit();
        self.edges.deinit();
        self.deadlock_detector.deinit();

        // Close WAL if it exists
        if (self.wal) |*w| {
            w.close();
        }

        // Free WAL path
        if (self.wal_path.len > 0) {
            self.allocator.free(self.wal_path);
        }
    }

    // Thread-safe node insertion
    pub inline fn insert_node(self: *Database, id: u64, kind: u32) !void {
        assert(id > 0);

        // Acquire write lock
        self.rwlock.writeLock();
        defer self.rwlock.writeUnlock();

        // Check for deadlock
        try self.deadlock_detector.acquireLock(@intCast(id));

        const node = Node{
            .id = id,
            .kind = kind,
            .created_at = std.time.timestamp(),
        };

        try self.nodes.put(id, node);
        _ = self.node_counter.increment();

        // Log to WAL if available
        if (self.wal) |*w| {
            w.append_insert_node_soa(id, @as(u8, @truncate(kind))) catch |err| {
                std.debug.print("⚠️  WAL write failed: {}\n", .{err});
            };
        }

        self.deadlock_detector.releaseLock(@intCast(id));
    }

    // Lock-free node insertion (for high-performance scenarios)
    pub inline fn insert_node_lockfree(self: *Database, kind: u32) !u64 {
        // Use seqlock for lock-free writes
        self.seqlock.writeLock();
        defer self.seqlock.writeUnlock();

        const id = self.node_id_generator.generate();
        const node = Node{
            .id = id,
            .kind = kind,
            .created_at = std.time.timestamp(),
        };

        try self.nodes.put(id, node);
        _ = self.node_counter.increment();

        return id;
    }

    // Thread-safe edge insertion
    pub inline fn insert_edge(self: *Database, from: u64, to: u64, label: u32) !void {
        assert(from > 0);
        assert(to > 0);
        assert(from != to); // No self-loops for now

        // Acquire write lock
        self.rwlock.writeLock();
        defer self.rwlock.writeUnlock();

        // Check for deadlock (order locks by ID to prevent deadlock)
        const min_id = @min(from, to);
        const max_id = @max(from, to);
        try self.deadlock_detector.acquireLock(@intCast(min_id));
        try self.deadlock_detector.acquireLock(@intCast(max_id));

        const edge_id = self.edge_id_generator.generate();
        const edge = Edge{
            .id = edge_id,
            .from = from,
            .to = to,
            .label = label,
            .created_at = std.time.timestamp(),
        };

        try self.edges.put(edge_id, edge);
        _ = self.edge_counter.increment();

        // Log to WAL if available
        if (self.wal) |*w| {
            w.append_insert_edge_soa(from, to, @as(u16, @truncate(label))) catch |err| {
                std.debug.print("⚠️  WAL write failed: {}\n", .{err});
            };
        }

        self.deadlock_detector.releaseLock(@intCast(max_id));
        self.deadlock_detector.releaseLock(@intCast(min_id));
    }

    // Lock-free edge insertion
    pub inline fn insert_edge_lockfree(self: *Database, from: u64, to: u64, label: u32) !u64 {
        assert(from > 0);
        assert(to > 0);
        assert(from != to);

        self.seqlock.writeLock();
        defer self.seqlock.writeUnlock();

        const edge_id = self.edge_id_generator.generate();
        const edge = Edge{
            .id = edge_id,
            .from = from,
            .to = to,
            .label = label,
            .created_at = std.time.timestamp(),
        };

        try self.edges.put(edge_id, edge);
        _ = self.edge_counter.increment();

        return edge_id;
    }

    // Thread-safe node lookup with read lock
    pub inline fn lookup_node(self: *Database, id: u64) ?u64 {
        assert(id > 0);

        self.rwlock.readLock();
        defer self.rwlock.readUnlock();

        if (self.nodes.contains(id)) {
            return id;
        }
        return null;
    }

    // Lock-free node lookup using seqlock
    pub inline fn lookup_node_lockfree(self: *Database, id: u64) ?u64 {
        assert(id > 0);

        var retries: u32 = 0;
        while (retries < 10) { // Max retries to prevent infinite loops
            const seq_start = self.seqlock.readBegin();

            if (self.nodes.contains(id)) {
                if (self.seqlock.readEnd(seq_start)) {
                    return id;
                }
            } else {
                if (self.seqlock.readEnd(seq_start)) {
                    return null;
                }
            }

            retries += 1;
            _ = self.metrics.seqlock_retries.increment();
        }

        return null; // Fallback after max retries
    }

    // Thread-safe statistics using atomic counters
    pub inline fn get_stats(self: *Database) DatabaseStats {
        return DatabaseStats{
            .memory = MemoryStats{
                .nodes = NodeStats{
                    .node_count = @intCast(self.node_counter.load()),
                    .node_capacity = 10000, // Static capacity for now
                    .edge_count = @intCast(self.edge_counter.load()),
                    .edge_capacity = 50000, // Static capacity for now
                },
            },
        };
    }

    // Get detailed concurrency metrics
    pub inline fn get_concurrency_stats(self: *Database) concurrency.ConcurrencyStats {
        return self.metrics.getStats();
    }

    // Transaction support
    pub inline fn begin_transaction(self: *Database, isolation: concurrency.IsolationLevel) !concurrency.Transaction {
        return concurrency.Transaction.init(self.allocator, self.node_id_generator.generate(), isolation);
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
