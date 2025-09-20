// NenDB Embedded - Single-User, Local Database
// Optimized for desktop, mobile, IoT, and single-user applications

const std = @import("std");

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
    
    // Performance settings
    enable_simd: bool = true,
    enable_wal: bool = true,
    wal_buffer_size: u32 = 1024 * 1024, // 1MB
    
    // Data directory
    data_dir: []const u8 = "data",
    
    // Logging
    log_level: LogLevel = .info,
};

// =============================================================================
// Simple Graph Database Implementation
// =============================================================================

const Node = struct {
    id: u64,
    kind: u8,
    properties: []const u8,
};

const Edge = struct {
    from: u64,
    to: u64,
    label: u16,
    properties: []const u8,
};

const GraphStats = struct {
    node_count: u32,
    edge_count: u32,
    utilization: f32,
};

// =============================================================================
// Embedded Database
// =============================================================================

pub const EmbeddedDB = struct {
    allocator: std.mem.Allocator,
    config: EmbeddedConfig,
    nodes: std.array_list.Managed(Node),
    edges: std.array_list.Managed(Edge),
    is_initialized: bool = false,
    is_shutdown: bool = false,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, config: EmbeddedConfig) !Self {
        var self = Self{
            .allocator = allocator,
            .config = config,
            .nodes = std.array_list.Managed(Node).init(allocator),
            .edges = std.array_list.Managed(Edge).init(allocator),
        };
        
        // Initialize with capacity
        try self.nodes.ensureTotalCapacity(config.max_nodes);
        try self.edges.ensureTotalCapacity(config.max_edges);
        
        self.is_initialized = true;
        return self;
    }
    
    pub fn deinit(self: *Self) void {
        self.nodes.deinit();
        self.edges.deinit();
        self.is_shutdown = true;
    }
    
    pub fn addNode(self: *Self, id: u64, kind: u8, properties: []const u8) !void {
        if (self.is_shutdown) return;
        
        const node = Node{
            .id = id,
            .kind = kind,
            .properties = properties,
        };
        
        try self.nodes.append(node);
    }
    
    pub fn addEdge(self: *Self, from: u64, to: u64, label: u16, properties: []const u8) !void {
        if (self.is_shutdown) return;
        
        const edge = Edge{
            .from = from,
            .to = to,
            .label = label,
            .properties = properties,
        };
        
        try self.edges.append(edge);
    }
    
    pub fn getStats(self: *Self) GraphStats {
        return GraphStats{
            .node_count = @intCast(self.nodes.items.len),
            .edge_count = @intCast(self.edges.items.len),
            .utilization = @as(f32, @floatFromInt(self.nodes.items.len)) / @as(f32, @floatFromInt(self.config.max_nodes)) * 100.0,
        };
    }
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
    std.debug.print("Version: v0.2.2-beta | Zig: {s}\n", .{@import("builtin").zig_version_string});
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
    try db.addNode(2, 1, "Bob");   // id=2, kind=1 (user), properties="Bob"
    try db.addNode(3, 2, "Widget"); // id=3, kind=2 (product), properties="Widget"
    
    std.debug.print("  • Added nodes: Alice, Bob, Widget\n", .{});
    
    // Add some edges
    try db.addEdge(1, 2, 1, "friends_with"); // from=1, to=2, label=1, properties="friends_with"
    try db.addEdge(1, 3, 2, "purchased");    // from=1, to=3, label=2, properties="purchased"
    try db.addEdge(2, 3, 3, "recommended");  // from=2, to=3, label=3, properties="recommended"
    
    std.debug.print("  • Added edges: Alice -> Bob (friends), Alice -> Widget (purchased), Bob -> Widget (recommended)\n", .{});
    
    // Get stats
    const stats = db.getStats();
    std.debug.print("  • Database stats: {} nodes, {} edges\n", .{ stats.node_count, stats.edge_count });
    
    std.debug.print("\n✅ Embedded database demo completed successfully!\n", .{});
}