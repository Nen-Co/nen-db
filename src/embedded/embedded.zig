// NenDB Embedded - Single-User, Local Database
// Optimized for desktop, mobile, IoT, and single-user applications

const std = @import("std");
const assert = std.debug.assert;

// Core imports
const GraphDB = @import("../shared/core/graphdb.zig").GraphDB;
const constants = @import("../shared/constants.zig");
const concurrency = @import("../shared/concurrency/concurrency.zig");

// =============================================================================
// Embedded Database Configuration
// =============================================================================

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};

pub const EmbeddedConfig = struct {
    // Memory configuration
    max_nodes: u32 = 100_000,
    max_edges: u32 = 500_000,
    max_embeddings: u32 = 10_000,
    embedding_dims: u32 = 256,

    // Storage configuration
    data_dir: []const u8 = "nendb_data",
    enable_wal: bool = true,
    wal_buffer_size: u32 = 1024 * 1024, // 1MB

    // Performance configuration
    enable_simd: bool = true,
    enable_concurrency: bool = true,
    max_concurrent_operations: u32 = 4,

    // Memory prediction
    enable_memory_prediction: bool = true,
    memory_safety_margin: f32 = 1.5,

    // Logging
    log_level: LogLevel = .info,
};

// =============================================================================
// Embedded Database Engine
// =============================================================================

pub const EmbeddedDB = struct {
    // Core engine
    graphdb: GraphDB,
    allocator: std.mem.Allocator,

    // Configuration
    config: EmbeddedConfig,

    // Concurrency
    rwlock: concurrency.ReadWriteLock,
    operation_counter: concurrency.AtomicCounter,

    // Memory management
    memory_stats: MemoryStats,

    // Storage
    wal: ?WAL = null,

    // State
    is_initialized: bool = false,
    is_shutdown: bool = false,

    const Self = @This();

    // =============================================================================
    // Initialization and Lifecycle
    // =============================================================================

    pub fn init(allocator: std.mem.Allocator, config: EmbeddedConfig) !Self {
        var self = Self{
            .graphdb = undefined,
            .allocator = allocator,
            .config = config,
            .rwlock = concurrency.ReadWriteLock{},
            .operation_counter = concurrency.AtomicCounter{},
            .memory_stats = MemoryStats{
                .nodes = NodeStats{
                    .node_count = 0,
                    .node_capacity = config.max_nodes,
                    .edge_count = 0,
                    .edge_capacity = config.max_edges,
                },
                .total_memory = 0,
                .utilization = 0.0,
            },
        };

        // Initialize core graph database
        try self.graphdb.init_inplace(allocator, "embedded_data");

        // Initialize WAL if enabled
        if (config.enable_wal) {
            self.wal = try WAL.init(allocator, config.data_dir, config.wal_buffer_size);
        }

        // Create data directory
        try std.fs.cwd().makePath(config.data_dir);

        self.is_initialized = true;
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.is_shutdown) return;

        // Flush WAL
        if (self.wal) |*wal| {
            wal.flush() catch {};
            wal.deinit();
        }

        // Deinitialize core database
        self.graphdb.deinit();

        self.is_shutdown = true;
    }

    // =============================================================================
    // Core Database Operations
    // =============================================================================

    pub fn addNode(self: *Self, id: u64, kind: u8, properties: ?[]const u8) !void {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.writeLock();
        defer self.rwlock.writeUnlock();

        _ = self.operation_counter.increment();

        // Add to core database
        try self.graphdb.insert_node(id, kind);

        // Update memory stats
        self.memory_stats.nodes.node_count += 1;
        self.memory_stats.utilization = self.memory_stats.nodes.getUtilization();

        // Write to WAL
        if (self.wal) |*wal| {
            try wal.writeNodeOperation(.add, id, kind, properties);
        }

        self.log(.debug, "Added node {d} of kind {d}", .{ id, kind });
    }

    pub fn addEdge(self: *Self, from: u64, to: u64, label: u16, properties: ?[]const u8) !void {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.writeLock();
        defer self.rwlock.writeUnlock();

        _ = self.operation_counter.increment();

        // Add to core database
        try self.graphdb.insert_edge(from, to, label);

        // Update memory stats
        self.memory_stats.nodes.edge_count += 1;
        self.memory_stats.utilization = self.memory_stats.nodes.getUtilization();

        // Write to WAL
        if (self.wal) |*wal| {
            try wal.writeEdgeOperation(.add, from, to, label, properties);
        }

        self.log(.debug, "Added edge {d} -> {d} with label {d}", .{ from, to, label });
    }

    pub fn getNode(self: *Self, id: u64) !?Node {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.readLock();
        defer self.rwlock.readUnlock();

        return self.graphdb.getNode(id);
    }

    pub fn getNeighbors(self: *Self, node_id: u64) ![]const u64 {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.readLock();
        defer self.rwlock.readUnlock();

        return self.graphdb.getNeighbors(node_id);
    }

    // =============================================================================
    // Graph Algorithms (Embedded Optimized)
    // =============================================================================

    pub fn bfs(self: *Self, start: u64, max_depth: u32) ![]const u64 {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.readLock();
        defer self.rwlock.readUnlock();

        return self.graphdb.bfs(start, max_depth);
    }

    pub fn dijkstra(self: *Self, start: u64, end: u64) !?f32 {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.readLock();
        defer self.rwlock.readUnlock();

        return self.graphdb.dijkstra(start, end);
    }

    pub fn pagerank(self: *Self, iterations: u32) ![]const f32 {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.readLock();
        defer self.rwlock.readUnlock();

        return self.graphdb.pagerank(iterations);
    }

    // =============================================================================
    // Memory Management
    // =============================================================================

    pub fn getMemoryStats(self: *Self) MemoryStats {
        return self.memory_stats;
    }

    pub fn getMemoryUtilization(self: *Self) f32 {
        return self.memory_stats.utilization;
    }

    pub fn isMemoryPressure(self: *Self) bool {
        return self.memory_stats.utilization > 0.8; // 80% threshold
    }

    // =============================================================================
    // Persistence
    // =============================================================================

    pub fn save(self: *Self, filename: []const u8) !void {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.readLock();
        defer self.rwlock.readUnlock();

        // Flush WAL first
        if (self.wal) |*wal| {
            try wal.flush();
        }

        // Save to file
        try self.graphdb.save(filename);

        self.log(.info, "Database saved to {s}", .{filename});
    }

    pub fn load(self: *Self, filename: []const u8) !void {
        if (self.is_shutdown) return error.DatabaseShutdown;

        self.rwlock.writeLock();
        defer self.rwlock.writeUnlock();

        // Load from file
        try self.graphdb.load(filename);

        // Update stats
        self.memory_stats.nodes.node_count = self.graphdb.getNodeCount();
        self.memory_stats.nodes.edge_count = self.graphdb.getEdgeCount();
        self.memory_stats.utilization = self.memory_stats.nodes.getUtilization();

        self.log(.info, "Database loaded from {s}", .{filename});
    }

    // =============================================================================
    // Utility Functions
    // =============================================================================

    fn log(self: *Self, level: LogLevel, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(level) < @intFromEnum(self.config.log_level)) return;

        const level_str = switch (level) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };

        std.debug.print("[{s}] NenDB Embedded: " ++ format ++ "\n", .{level_str} ++ args);
    }
};

// =============================================================================
// Supporting Types
// =============================================================================

pub const Node = struct {
    id: u64,
    kind: u8,
    properties: ?[]const u8,
};

pub const Edge = struct {
    from: u64,
    to: u64,
    label: u16,
    properties: ?[]const u8,
};

pub const NodeStats = struct {
    node_count: u64,
    node_capacity: u64,
    edge_count: u64,
    edge_capacity: u64,

    pub inline fn getUtilization(self: NodeStats) f32 {
        const total_used = self.node_count + self.edge_count;
        const total_capacity = self.node_capacity + self.edge_capacity;
        return @as(f32, @floatFromInt(total_used)) / @as(f32, @floatFromInt(total_capacity));
    }
};

pub const MemoryStats = struct {
    nodes: NodeStats,
    total_memory: u64,
    utilization: f32,
};

// =============================================================================
// Write-Ahead Log (WAL) for Embedded
// =============================================================================

const WAL = struct {
    allocator: std.mem.Allocator,
    data_dir: []const u8,
    buffer: std.array_list.Managed(u8),
    file: ?std.fs.File = null,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8, buffer_size: u32) !Self {
        var self = Self{
            .allocator = allocator,
            .data_dir = data_dir,
            .buffer = std.array_list.Managed(u8).init(allocator),
        };

        try self.buffer.ensureTotalCapacity(buffer_size);

        // Open WAL file
        const wal_path = try std.fmt.allocPrint(allocator, "{s}/wal.log", .{data_dir});
        defer allocator.free(wal_path);

        self.file = std.fs.cwd().createFile(wal_path, .{}) catch |err| {
            if (err != error.FileAlreadyExists) return err;
            self.file = std.fs.cwd().openFile(wal_path, .{}) catch null;
            return self;
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.file) |f| f.close();
        self.buffer.deinit();
    }

    pub fn writeNodeOperation(self: *Self, op: Operation, id: u64, kind: u8, properties: ?[]const u8) !void {
        _ = self;
        _ = op;
        _ = id;
        _ = kind;
        _ = properties;
        // TODO: Implement WAL writing
    }

    pub fn writeEdgeOperation(self: *Self, op: Operation, from: u64, to: u64, label: u16, properties: ?[]const u8) !void {
        _ = self;
        _ = op;
        _ = from;
        _ = to;
        _ = label;
        _ = properties;
        // TODO: Implement WAL writing
    }

    pub fn flush(self: *Self) !void {
        if (self.file) |f| {
            try f.writeAll(self.buffer.items);
            try f.sync();
            self.buffer.clearRetainingCapacity();
        }
    }
};

const Operation = enum {
    add,
    remove,
    update,
};

// =============================================================================
// Error Types
// =============================================================================

pub const EmbeddedError = error{
    DatabaseShutdown,
    ConcurrencyError,
    MemoryPressure,
    InvalidConfiguration,
    PersistenceError,
};

// =============================================================================
// Main Entry Point
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 NenDB Embedded - Single-User Graph Database\n", .{});
    std.debug.print("==============================================\n", .{});
    std.debug.print("Version: {s} | Zig: {s}\n", .{ constants.VERSION_STRING, @import("builtin").zig_version_string });
    std.debug.print("\n", .{});

    // Initialize embedded database
    const config = EmbeddedConfig{
        .max_nodes = 100_000,
        .max_edges = 500_000,
        .max_embeddings = 10_000,
        .embedding_dims = 256,
    };

    var db = EmbeddedDB.init(allocator, config) catch |err| {
        std.debug.print("❌ Failed to initialize embedded database: {}\n", .{err});
        return;
    };
    defer db.deinit();

    std.debug.print("✅ Embedded database initialized\n", .{});
    std.debug.print("  • Max nodes: {}\n", .{config.max_nodes});
    std.debug.print("  • Max edges: {}\n", .{config.max_edges});
    std.debug.print("  • Max embeddings: {}\n", .{config.max_embeddings});
    std.debug.print("  • Embedding dimensions: {}\n", .{config.embedding_dims});
    std.debug.print("\n", .{});

    // Demo operations
    std.debug.print("🔧 Running embedded database demo...\n", .{});

    // Add some nodes
    try db.addNode(1, 1, "Alice"); // id=1, kind=1 (user), properties="Alice"
    try db.addNode(2, 1, "Bob"); // id=2, kind=1 (user), properties="Bob"
    try db.addNode(3, 2, "Widget"); // id=3, kind=2 (product), properties="Widget"

    std.debug.print("  • Added nodes: Alice, Bob, Widget\n", .{});

    // Add some edges
    try db.addEdge(1, 2, 1, "friends_with"); // from=1, to=2, label=1, properties="friends_with"
    try db.addEdge(1, 3, 2, "purchased"); // from=1, to=3, label=2, properties="purchased"
    try db.addEdge(2, 3, 3, "recommended"); // from=2, to=3, label=3, properties="recommended"

    std.debug.print("  • Added edges: Alice -> Bob (friends), Alice -> Widget (purchased), Bob -> Widget (recommended)\n", .{});

    // Get stats
    const stats = db.getMemoryStats();
    std.debug.print("  • Database stats: {} nodes, {} edges\n", .{ stats.nodes.node_count, stats.nodes.edge_count });

    std.debug.print("\n✅ Embedded database demo completed successfully!\n", .{});
}
