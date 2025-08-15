// NenDB - Production Graph Database Engine
// Following TigerBeetle's architecture for mission-critical performance

const std = @import("std");
const constants = @import("constants.zig");
const pool = @import("memory/pool.zig");
const wal = @import("memory/wal.zig");

// Batch operation definitions (TigerBeetle-style fixed structs)
pub const NodeDef = extern struct { 
    id: u64,  // Changed to u64 for performance
    kind: u8, 
    reserved: [7]u8 = [_]u8{0} ** 7,
    props: [constants.data.node_props_size]u8 = [_]u8{0} ** constants.data.node_props_size,
};

pub const EdgeDef = extern struct { 
    from: u64,  // Node IDs instead of string references
    to: u64, 
    label: u16, 
    reserved: [6]u8 = [_]u8{0} ** 6,
    props: [constants.data.edge_props_size]u8 = [_]u8{0} ** constants.data.edge_props_size,
};

pub const EmbeddingDef = extern struct {
    node_id: u64,
    reserved: [8]u8 = [_]u8{0} ** 8,
    vector: [constants.data.embedding_dimensions]f32,
};

// Internal edge indexing
const EdgeIndex = struct { 
    from: usize, 
    to: usize, 
    label: u16 
};

// Batch insert structures (TigerBeetle batch pattern)
pub const BatchNodeInsert = struct {
    nodes: []const NodeDef,
};

pub const BatchEdgeInsert = struct {
    edges: []const EdgeDef,
};

pub const BatchEmbeddingInsert = struct {
    embeddings: []const EmbeddingDef,
};

// Result structures
pub const BatchResult = struct {
    success_count: u32,
    error_count: u32,
    errors: []constants.NenDBError,
};

// Memory statistics for monitoring
pub const DatabaseStats = struct {
    nodes: pool.MemoryStats,
    edges: pool.MemoryStats,
    embeddings: pool.MemoryStats,
    total_memory_bytes: u64,
    wal_operations: u64,
};

// The main NenDB engine (production-ready)
pub const NenDB = struct {
    const Self = @This();
    
    // Static memory pools (zero dynamic allocation)
    node_pool: pool.NodePool,
    edge_pool: pool.EdgePool,
    embedding_pool: pool.EmbeddingPool,
    
    // Write-Ahead Log for durability
    wal: wal.WAL,
    
    // Configuration
    allocator: std.mem.Allocator,
    data_dir: []const u8,
    
    // Statistics
    operations_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, node_pool: *pool.NodePool, edge_pool: *pool.EdgePool, embedding_pool: *pool.EmbeddingPool) !NenDB {
        return NenDB{
            .node_pool = node_pool,
            .edge_pool = edge_pool,
            .embedding_pool = embedding_pool,
            .id_to_idx = std.StringHashMap(usize).init(allocator),
            .edge_indices = std.ArrayList(EdgeIndex).init(allocator),
        };
    }

    pub fn deinit(self: *NenDB) void {
        self.id_to_idx.deinit();
        self.edge_indices.deinit();
    }

    /// Batch insert nodes - core NenDB operation
    pub fn batch_insert_nodes(self: *NenDB, batch: BatchNodeInsert) ![]?usize {
        var results = try self.id_to_idx.allocator.alloc(?usize, batch.nodes.len);
        for (batch.nodes, 0..) |n, i| {
            const node = pool.Node{ 
                .id = @as(u64, self.id_to_idx.count()), 
                .kind = n.kind, 
                .props = n.props 
            };
            
            // WAL: log before allocation for durability
            try pool.wal_append_node(node, ".");
            
            const idx = self.node_pool.alloc(node);
            if (idx) |real_idx| {
                try self.id_to_idx.put(n.id, real_idx);
                results[i] = real_idx;
            } else {
                results[i] = null;
            }
        }
        return results;
    }

    /// Batch insert edges - core NenDB operation
    pub fn batch_insert_edges(self: *NenDB, batch: BatchEdgeInsert) ![]?usize {
        var results = try self.id_to_idx.allocator.alloc(?usize, batch.edges.len);
        for (batch.edges, 0..) |e, i| {
            const from_idx = self.id_to_idx.get(e.from) orelse null;
            const to_idx = self.id_to_idx.get(e.to) orelse null;
            
            if (from_idx == null or to_idx == null) {
                results[i] = null;
                continue;
            }
            
            const edge = pool.Edge{ 
                .from = @as(u64, from_idx.?), 
                .to = @as(u64, to_idx.?), 
                .label = e.label, 
                .props = e.props 
            };
            
            // WAL: log before allocation for durability
            try pool.wal_append_edge(edge, ".");
            
            const idx = self.edge_pool.alloc(edge);
            if (idx) |real_idx| {
                try self.edge_indices.append(.{ 
                    .from = from_idx.?, 
                    .to = to_idx.?, 
                    .label = e.label 
                });
                results[i] = real_idx;
            } else {
                results[i] = null;
            }
        }
        return results;
    }

    /// Batch insert embeddings - AI-native feature
    pub fn batch_insert_embeddings(self: *NenDB, batch: BatchEmbeddingInsert) ![]?usize {
        var results = try self.id_to_idx.allocator.alloc(?usize, batch.embeddings.len);
        for (batch.embeddings, 0..) |e, i| {
            const node_idx = self.id_to_idx.get(e.node_id) orelse null;
            if (node_idx == null) {
                results[i] = null;
                continue;
            }
            
            const emb = pool.Embedding{ 
                .node_id = @as(u64, node_idx.?), 
                .vector = e.vector 
            };
            
            // WAL: log before allocation for durability
            try pool.wal_append_embedding(emb, ".");
            
            const idx = self.embedding_pool.alloc(emb);
            results[i] = idx;
        }
        return results;
    }

    /// Assemble context for AI applications
    pub fn assemble_context(self: *NenDB, id: []const u8, buf: []u8) !usize {
        var written: usize = 0;
        const idx = self.id_to_idx.get(id) orelse return 0;
        const node = self.node_pool.get(idx) orelse return 0;
        const n = node.*;
        
        // Write node info
        const out = try std.fmt.bufPrint(buf[written..], "Node {} (kind: {}): ", .{ n.id, n.kind });
        written += out.len;
        
        // Add properties as string
        var prop_end: usize = 0;
        while (prop_end < node.props.len and node.props[prop_end] != 0) : (prop_end += 1) {}
        const out2 = try std.fmt.bufPrint(buf[written..], "{s}\n", .{ n.props[0..prop_end] });
        written += out2.len;
        
        // Add connected nodes
        var found = false;
        for (self.edge_indices.items) |edge| {
            if (edge.from == idx) {
                if (!found) {
                    const out3 = try std.fmt.bufPrint(buf[written..], "  Connected to: ", .{});
                    written += out3.len;
                    found = true;
                }
                const out4 = try std.fmt.bufPrint(buf[written..], "{} ", .{edge.to});
                written += out4.len;
            }
        }
        if (found) {
            const out5 = try std.fmt.bufPrint(buf[written..], "\n", .{});
            written += out5.len;
        }
        return written;
    }

    /// Load persistent state (snapshot + WAL replay)
    pub fn load_persistent_state(self: *NenDB, dir: []const u8) !void {
        try self.node_pool.load_from_disk(dir);
        try self.edge_pool.load_from_disk(dir);
        try self.embedding_pool.load_from_disk(dir);
        try self.node_pool.wal_replay(dir);
        try self.edge_pool.wal_replay(dir);
        try self.embedding_pool.wal_replay(dir);
    }

    /// Save persistent state (snapshot + truncate WAL)
    pub fn save_persistent_state(self: *NenDB, dir: []const u8) !void {
        try self.node_pool.save_to_disk(dir);
        try self.edge_pool.save_to_disk(dir);
        try self.embedding_pool.save_to_disk(dir);
        
        // Truncate WAL files after successful snapshot
        try truncate_file("{s}/nodes.wal", dir);
        try truncate_file("{s}/edges.wal", dir);
        try truncate_file("{s}/embeddings.wal", dir);
    }

    /// Get memory usage statistics
    pub fn get_memory_stats(self: *NenDB) MemoryStats {
        return MemoryStats{
            .nodes_used = self.node_pool.next,
            .nodes_capacity = pool.NODE_POOL_SIZE,
            .edges_used = self.edge_pool.next,
            .edges_capacity = pool.EDGE_POOL_SIZE,
            .embeddings_used = self.embedding_pool.next,
            .embeddings_capacity = pool.EMBEDDING_POOL_SIZE,
            .total_memory_bytes = @sizeOf(pool.NodePool) + @sizeOf(pool.EdgePool) + @sizeOf(pool.EmbeddingPool),
        };
    }

    fn truncate_file(comptime fmt: []const u8, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, fmt, .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true, .read = false });
        file.close();
    }
};

pub const MemoryStats = struct {
    nodes_used: usize,
    nodes_capacity: usize,
    edges_used: usize,
    edges_capacity: usize,
    embeddings_used: usize,
    embeddings_capacity: usize,
    total_memory_bytes: usize,
};
