// NenDB - Production Memory Pools
// Static, pre-allocated memory pools following TigerBeetle patterns

const std = @import("std");
const constants = @import("../constants.zig");

// Import configuration from constants
const NODE_POOL_SIZE = constants.memory.node_pool_size;
// Memory statistics structure
pub const MemoryStats = struct {
    capacity: u32,
    used: u32,
    free: u32,
    utilization: f32,
};

// Static Edge Pool - Pre-allocated, zero dynamic allocationnst NODE_POOL_SIZE = constants.memory.node_pool_size;
const EDGE_POOL_SIZE = constants.memory.edge_pool_size;
const EMBEDDING_POOL_SIZE = constants.memory.embedding_pool_size;
const EMBEDDING_DIM = constants.data.embedding_dimensions;
const CACHE_LINE_SIZE = constants.memory.cache_line_size;

// Core data structures (aligned for performance)
pub const Node = extern struct {
    id: u64,
    kind: u8,
    reserved: [7]u8 = [_]u8{0} ** 7, // Padding for alignment
    props: [constants.data.node_props_size]u8,

    comptime {
        std.debug.assert(@sizeOf(Node) % CACHE_LINE_SIZE == 0);
        std.debug.assert(@alignOf(Node) >= 8);
    }
};

pub const Edge = extern struct {
    from: u64,
    to: u64,
    label: u16,
    reserved: [6]u8 = [_]u8{0} ** 6, // Padding for alignment
    props: [constants.data.edge_props_size]u8,

    comptime {
        std.debug.assert(@alignOf(Edge) >= 8);
    }
};

pub const Embedding = extern struct {
    node_id: u64,
    vector: [EMBEDDING_DIM]f32,

    comptime {
        std.debug.assert(@alignOf(Embedding) >= 8);
    }
};

// Production Static Memory Pools (TigerBeetle-inspired)
pub const NodePool = struct {
    const Self = @This();

    // Static allocation - no dynamic memory
    nodes: [NODE_POOL_SIZE]Node align(CACHE_LINE_SIZE) = undefined,
    free_list: [NODE_POOL_SIZE]?u32 = [_]?u32{null} ** NODE_POOL_SIZE,
    next_free: u32 = 0,
    used_count: u32 = 0,

    // Hash table for O(1) lookups by ID
    hash_table: [NODE_POOL_SIZE * 2]?u32 = [_]?u32{null} ** (NODE_POOL_SIZE * 2), // 2x size for lower collision

    pub fn init() Self {
        var self = Self{};

        // Initialize free list
        for (self.free_list[0..NODE_POOL_SIZE], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }

        return self;
    }

    pub fn alloc(self: *Self, node: Node) !u32 {
        if (self.used_count >= NODE_POOL_SIZE) {
            return constants.NenDBError.PoolExhausted;
        }

        // Get next free slot
        const slot_idx = self.next_free;
        if (slot_idx >= NODE_POOL_SIZE) {
            return constants.NenDBError.PoolExhausted;
        }

        const node_idx = self.free_list[slot_idx] orelse return constants.NenDBError.PoolExhausted;

        // Store node
        self.nodes[node_idx] = node;

        // Update free list
        self.free_list[slot_idx] = null;
        self.next_free += 1;
        self.used_count += 1;

        // Add to hash table for fast lookup
        const hash = self.hash_node_id(node.id);
        var probe = hash;
        while (self.hash_table[probe] != null) {
            probe = (probe + 1) % self.hash_table.len;
        }
        self.hash_table[probe] = node_idx;

        return node_idx;
    }

    pub fn get(self: *const Self, idx: u32) ?*const Node {
        if (idx >= NODE_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null; // Slot is free
        return &self.nodes[idx];
    }

    pub fn get_mut(self: *Self, idx: u32) ?*Node {
        if (idx >= NODE_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null; // Slot is free
        return &self.nodes[idx];
    }

    pub fn get_by_id(self: *const Self, node_id: u64) ?*const Node {
        const hash = self.hash_node_id(node_id);
        var probe = hash;

        while (self.hash_table[probe]) |node_idx| {
            if (self.nodes[node_idx].id == node_id) {
                return &self.nodes[node_idx];
            }
            probe = (probe + 1) % self.hash_table.len;
        }

        return null;
    }

    pub fn free(self: *Self, idx: u32) !void {
        if (idx >= NODE_POOL_SIZE) return constants.NenDBError.InvalidNodeID;
        if (self.free_list[idx] != null) return; // Already free

        const node = &self.nodes[idx];

        // Remove from hash table
        const hash = self.hash_node_id(node.id);
        var probe = hash;
        while (self.hash_table[probe]) |node_idx| {
            if (node_idx == idx) {
                self.hash_table[probe] = null;
                break;
            }
            probe = (probe + 1) % self.hash_table.len;
        }

        // Add back to free list
        if (self.next_free > 0) {
            self.next_free -= 1;
            self.free_list[self.next_free] = idx;
            self.used_count -= 1;
        }

        // Clear node data
        node.* = std.mem.zeroes(Node);
    }

    fn hash_node_id(self: *const Self, node_id: u64) usize {
        // self is used below
        // Simple but effective hash function
        var hash = node_id;
        hash ^= hash >> 33;
        hash *%= 0xff51afd7ed558ccd;
        hash ^= hash >> 33;
        hash *%= 0xc4ceb9fe1a85ec53;
        hash ^= hash >> 33;
        return @intCast(hash % self.hash_table.len);
    }

    pub fn get_stats(self: *const Self) MemoryStats {
        return MemoryStats{
            .capacity = NODE_POOL_SIZE,
            .used = self.used_count,
            .free = NODE_POOL_SIZE - self.used_count,
            .utilization = @as(f32, @floatFromInt(self.used_count)) / @as(f32, @floatFromInt(NODE_POOL_SIZE)),
        };
    }
};

// Production Embedding Pool
pub const EmbeddingPool = struct {
    const Self = @This();

    embeddings: [EMBEDDING_POOL_SIZE]Embedding align(CACHE_LINE_SIZE) = undefined,
    free_list: [EMBEDDING_POOL_SIZE]?u32 = [_]?u32{null} ** EMBEDDING_POOL_SIZE,
    next_free: u32 = 0,
    used_count: u32 = 0,

    pub fn init() Self {
        var self = Self{};

        // Initialize free list
        for (self.free_list[0..EMBEDDING_POOL_SIZE], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }

        return self;
    }

    pub fn alloc(self: *Self, embedding: Embedding) !u32 {
        if (self.used_count >= EMBEDDING_POOL_SIZE) {
            return constants.NenDBError.PoolExhausted;
        }

        const slot_idx = self.next_free;
        if (slot_idx >= EMBEDDING_POOL_SIZE) {
            return constants.NenDBError.PoolExhausted;
        }

        const embedding_idx = self.free_list[slot_idx] orelse return constants.NenDBError.PoolExhausted;

        self.embeddings[embedding_idx] = embedding;
        self.free_list[slot_idx] = null;
        self.next_free += 1;
        self.used_count += 1;

        return embedding_idx;
    }

    pub fn get(self: *const Self, idx: u32) ?*const Embedding {
        if (idx >= EMBEDDING_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null;
        return &self.embeddings[idx];
    }

    pub fn get_stats(self: *const Self) MemoryStats {
        return MemoryStats{
            .capacity = EMBEDDING_POOL_SIZE,
            .used = self.used_count,
            .free = EMBEDDING_POOL_SIZE - self.used_count,
            .utilization = @as(f32, @floatFromInt(self.used_count)) / @as(f32, @floatFromInt(EMBEDDING_POOL_SIZE)),
        };
    }
};

/// Save the node pool to disk as a binary file (nodes.bin in given dir)
pub fn save_to_disk(self: *NodePool, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.bin", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true, .read = false });
    defer file.close();
    try file.writer().writeAll(std.mem.sliceAsBytes(self.nodes[0..self.next]));
}

/// Load the node pool from disk (nodes.bin in given dir)
pub fn load_from_disk(self: *NodePool, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.bin", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    const file_size = (try file.stat()).size;
    const count = file_size / @sizeOf(Node);
    if (count > NODE_POOL_SIZE) return error.Overflow;
    const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
    defer std.heap.page_allocator.free(buf);
    @memcpy(self.nodes[0..count], std.mem.bytesAsSlice(Node, buf));
    self.next = count;
}

/// Replay the WAL to restore state after loading snapshot
pub fn wal_replay(self: *NodePool, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.wal", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    const file_size = (try file.stat()).size;
    const count = file_size / @sizeOf(Node);
    if (self.next + count > NODE_POOL_SIZE) return error.Overflow;
    const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
    defer std.heap.page_allocator.free(buf);
    for (0..count) |i| {
        self.nodes[self.next] = std.mem.bytesAsValue(Node, buf[i * @sizeOf(Node) ..][0..@sizeOf(Node)]).*;
        self.next += 1;
    }
}
//};

// Static Edge Pool - Pre-allocated, zero dynamic allocation
// Production Edge Pool with TigerBeetle patterns
pub const EdgePool = struct {
    const Self = @This();

    edges: [EDGE_POOL_SIZE]Edge align(CACHE_LINE_SIZE) = undefined,
    free_list: [EDGE_POOL_SIZE]?u32 = [_]?u32{null} ** EDGE_POOL_SIZE,
    next_free: u32 = 0,
    used_count: u32 = 0,

    // Hash table for edge lookups (by from->to pair)
    hash_table: [EDGE_POOL_SIZE * 2]?u32 = [_]?u32{null} ** (EDGE_POOL_SIZE * 2),

    pub fn init() Self {
        var self = Self{};

        // Initialize free list
        for (self.free_list[0..EDGE_POOL_SIZE], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }

        return self;
    }

    pub fn alloc(self: *Self, edge: Edge) !u32 {
        if (self.used_count >= EDGE_POOL_SIZE) {
            return constants.NenDBError.PoolExhausted;
        }

        const slot_idx = self.next_free;
        if (slot_idx >= EDGE_POOL_SIZE) {
            return constants.NenDBError.PoolExhausted;
        }

        const edge_idx = self.free_list[slot_idx] orelse return constants.NenDBError.PoolExhausted;

        self.edges[edge_idx] = edge;
        self.free_list[slot_idx] = null;
        self.next_free += 1;
        self.used_count += 1;

        // Add to hash table for fast lookup
        const hash = self.hash_edge(edge.from, edge.to);
        var probe = hash;
        while (self.hash_table[probe] != null) {
            probe = (probe + 1) % self.hash_table.len;
        }
        self.hash_table[probe] = edge_idx;

        return edge_idx;
    }

    pub fn get(self: *const Self, idx: u32) ?*const Edge {
        if (idx >= EDGE_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null;
        return &self.edges[idx];
    }

    pub fn get_by_nodes(self: *const Self, from: u64, to: u64) ?*const Edge {
        const hash = self.hash_edge(from, to);
        var probe = hash;

        while (self.hash_table[probe]) |edge_idx| {
            const edge = &self.edges[edge_idx];
            if (edge.from == from and edge.to == to) {
                return edge;
            }
            probe = (probe + 1) % self.hash_table.len;
        }

        return null;
    }

    fn hash_edge(self: *const Self, from: u64, to: u64) usize {
        // self is used below
        // Combine the two node IDs for edge hash
        var hash = from ^ (to << 1);
        hash ^= hash >> 33;
        hash *%= 0xff51afd7ed558ccd;
        hash ^= hash >> 33;
        return @intCast(hash % self.hash_table.len);
    }

    pub fn get_stats(self: *const Self) MemoryStats {
        return MemoryStats{
            .capacity = EDGE_POOL_SIZE,
            .used = self.used_count,
            .free = EDGE_POOL_SIZE - self.used_count,
            .utilization = @as(f32, @floatFromInt(self.used_count)) / @as(f32, @floatFromInt(EDGE_POOL_SIZE)),
        };
    }

    /// Save the edge pool to disk as a binary file (edges.bin in given dir)
    pub fn save_to_disk(self: *EdgePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true, .read = false });
        defer file.close();
        try file.writer().writeAll(std.mem.sliceAsBytes(self.edges[0..self.next]));
    }

    /// Load the edge pool from disk (edges.bin in given dir)
    pub fn load_from_disk(self: *EdgePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Edge);
        if (count > EDGE_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        @memcpy(self.edges[0..count], std.mem.bytesAsSlice(Edge, buf));
        self.next = count;
    }

    /// Replay the WAL to restore state after loading snapshot
    pub fn wal_replay(self: *EdgePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.wal", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Edge);
        if (self.next + count > EDGE_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        for (0..count) |i| {
            self.edges[self.next] = std.mem.bytesAsValue(Edge, buf[i * @sizeOf(Edge) ..][0..@sizeOf(Edge)]).*;
            self.next += 1;
        }
    }
};

// Static Embedding Pool - Pre-allocated, zero dynamic allocation

// WAL (Write-Ahead Logging) utilities
pub fn wal_append_node(node: Node, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.wal", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
    defer file.close();
    try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Node{node}));
}

pub fn wal_append_edge(edge: Edge, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.wal", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
    defer file.close();
    try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Edge{edge}));
}

pub fn wal_append_embedding(emb: Embedding, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/embeddings.wal", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
    defer file.close();
    try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Embedding{emb}));
}
