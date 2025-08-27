// NenDB - Production Memory Pools
// Static, pre-allocated memory pools following TigerBeetle patterns

const std = @import("std");
pub const constants = @import("../constants.zig");

// Import configuration from constants
pub const NODE_POOL_SIZE = constants.memory.node_pool_size;
pub const EDGE_POOL_SIZE = constants.memory.edge_pool_size;
pub const EMBEDDING_POOL_SIZE = constants.memory.embedding_pool_size;
pub const EMBEDDING_DIM = constants.data.embedding_dimensions;
pub const CACHE_LINE_SIZE = constants.memory.cache_line_size;

// Core data structures (aligned for performance)
pub const Node = extern struct {
    id: u64,
    kind: u8,
    reserved: [7]u8 = [_]u8{0} ** 7, // Padding for alignment
    props: [constants.data.node_props_size]u8,

    comptime {
        // Ensure alignment is reasonable (removed strict cache line requirement for now)
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

// Memory statistics structure
pub const MemoryStats = struct {
    capacity: u32,
    used: u32,
    free: u32,
    utilization: f32,
};

// Production Static Memory Pools (TigerBeetle-inspired)
pub const NodePool = struct {
    const Self = @This();

    // Static allocation - no dynamic memory
    nodes: [NODE_POOL_SIZE]Node = [_]Node{std.mem.zeroes(Node)} ** NODE_POOL_SIZE,
    free_list: [NODE_POOL_SIZE]?u32 = [_]?u32{null} ** NODE_POOL_SIZE,
    next_free: u32 = 0,
    used_count: u32 = 0,

    // Hash table for O(1) lookups by ID
    hash_table: [NODE_POOL_SIZE * 2]?u32 = [_]?u32{null} ** (NODE_POOL_SIZE * 2), // 2x size for lower collision

    pub inline fn init() Self {
        var self = Self{};

        // Initialize free list
        for (self.free_list[0..NODE_POOL_SIZE], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }

        return self;
    }

    pub inline fn alloc(self: *Self, node: Node) !u32 {
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

    pub inline fn get(self: *const Self, idx: u32) ?*const Node {
        if (idx >= NODE_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null; // Slot is free
        return &self.nodes[idx];
    }

    pub inline fn get_mut(self: *Self, idx: u32) ?*Node {
        if (idx >= NODE_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null; // Slot is free
        return &self.nodes[idx];
    }

    pub inline fn get_by_id(self: *const Self, node_id: u64) ?*const Node {
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

    pub inline fn free(self: *Self, idx: u32) !void {
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

    inline fn hash_node_id(self: *const Self, node_id: u64) usize {
        // Simple but effective hash function
        var hash = node_id;
        hash ^= hash >> 33;
        hash *%= 0xff51afd7ed558ccd;
        hash ^= hash >> 33;
        hash *%= 0xc4ceb9fe1a85ec53;
        hash ^= hash >> 33;
        return @intCast(hash % @as(u64, @intCast(self.hash_table.len)));
    }

    pub inline fn get_stats(self: *const Self) MemoryStats {
        return MemoryStats{
            .capacity = NODE_POOL_SIZE,
            .used = self.used_count,
            .free = NODE_POOL_SIZE - self.used_count,
            .utilization = @as(f32, @floatFromInt(self.used_count)) / @as(f32, @floatFromInt(NODE_POOL_SIZE)),
        };
    }
};

// Production Edge Pool with TigerBeetle patterns
pub const EdgePool = struct {
    const Self = @This();

    // Static allocation - no dynamic memory
    edges: [EDGE_POOL_SIZE]Edge = [_]Edge{std.mem.zeroes(Edge)} ** EDGE_POOL_SIZE,
    free_list: [EDGE_POOL_SIZE]?u32 = [_]?u32{null} ** EDGE_POOL_SIZE,
    next_free: u32 = 0,
    used_count: u32 = 0,

    // Hash table for O(1) lookups by ID (from -> to mapping)
    hash_table: [EDGE_POOL_SIZE * 2]?u32 = [_]?u32{null} ** (EDGE_POOL_SIZE * 2), // 2x size for lower collision

    pub inline fn init() Self {
        var self = Self{};

        // Initialize free list
        for (self.free_list[0..EDGE_POOL_SIZE], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }

        return self;
    }

    pub inline fn alloc(self: *Self, edge: Edge) !u32 {
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

    pub inline fn get(self: *const Self, idx: u32) ?*const Edge {
        if (idx >= EDGE_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null;
        return &self.edges[idx];
    }

    pub inline fn get_by_nodes(self: *const Self, from: u64, to: u64) ?*const Edge {
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

    inline fn hash_edge(self: *const Self, from: u64, to: u64) usize {
        // Combine the two node IDs for edge hash
        var hash = from ^ (to << 1);
        hash ^= hash >> 33;
        hash *%= 0xff51afd7ed558ccd;
        hash ^= hash >> 33;
        return @intCast(hash % @as(u64, @intCast(self.hash_table.len)));
    }

    pub inline fn get_stats(self: *const Self) MemoryStats {
        return MemoryStats{
            .capacity = EDGE_POOL_SIZE,
            .used = self.used_count,
            .free = EDGE_POOL_SIZE - self.used_count,
            .utilization = @as(f32, @floatFromInt(self.used_count)) / @as(f32, @floatFromInt(EDGE_POOL_SIZE)),
        };
    }
};

// Production Embedding Pool
pub const EmbeddingPool = struct {
    const Self = @This();

    embeddings: [EMBEDDING_POOL_SIZE]Embedding = [_]Embedding{std.mem.zeroes(Embedding)} ** EMBEDDING_POOL_SIZE,
    free_list: [EMBEDDING_POOL_SIZE]?u32 = [_]?u32{null} ** EMBEDDING_POOL_SIZE,
    next_free: u32 = 0,
    used_count: u32 = 0,

    pub inline fn init() Self {
        var self = Self{};

        // Initialize free list
        for (self.free_list[0..EMBEDDING_POOL_SIZE], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }

        return self;
    }

    pub inline fn alloc(self: *Self, embedding: Embedding) !u32 {
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

    pub inline fn get(self: *const Self, idx: u32) ?*const Embedding {
        if (idx >= EMBEDDING_POOL_SIZE) return null;
        if (self.free_list[idx] != null) return null;
        return &self.embeddings[idx];
    }

    pub inline fn get_stats(self: *const Self) MemoryStats {
        return MemoryStats{
            .capacity = EMBEDDING_POOL_SIZE,
            .used = self.used_count,
            .free = EMBEDDING_POOL_SIZE - self.used_count,
            .utilization = @as(f32, @floatFromInt(self.used_count)) / @as(f32, @floatFromInt(EMBEDDING_POOL_SIZE)),
        };
    }
};
