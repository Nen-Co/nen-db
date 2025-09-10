// NenDB WASM Library - Browser/Embedded Compatible Version
// Removes filesystem, networking, and threading dependencies

const std = @import("std");
const memory = @import("memory/pool_v2.zig");
const constants = @import("constants.zig");

// WASM-compatible GraphDB that operates entirely in-memory
pub const WasmGraphDB = struct {
    // Static memory pools - perfect for WASM's predictable memory model
    node_pool: memory.NodePool align(64),
    edge_pool: memory.EdgePool align(64),
    embedding_pool: memory.EmbeddingPool align(64),

    // No WAL, no filesystem - pure in-memory operation
    ops_count: u64 = 0,
    inserts_total: u64 = 0,
    lookups_total: u64 = 0,

    pub const WasmMemoryStats = struct {
        nodes: memory.MemoryStats,
        edges: memory.MemoryStats,
        embeddings: memory.MemoryStats,
    };

    pub fn init() WasmGraphDB {
        return WasmGraphDB{
            .node_pool = memory.NodePool.init(),
            .edge_pool = memory.EdgePool.init(),
            .embedding_pool = memory.EmbeddingPool.init(),
        };
    }

    pub fn deinit(self: *WasmGraphDB) void {
        // Static pools don't need deinitialization in WASM
        _ = self;
    }

    pub fn get_memory_stats(self: *const WasmGraphDB) WasmMemoryStats {
        return WasmMemoryStats{
            .nodes = self.node_pool.get_stats(),
            .edges = self.edge_pool.get_stats(),
            .embeddings = self.embedding_pool.get_stats(),
        };
    }

    pub fn add_node(self: *WasmGraphDB, id: u32, properties: []const u8) !u32 {
        _ = properties; // TODO: Process properties
        const node = memory.Node{
            .id = @as(u64, id),
            .kind = 0, // Default node kind
            .props = [_]u8{0} ** constants.data.node_props_size,
        };
        const node_idx = self.node_pool.alloc(node) catch return error.NodePoolFull;
        self.inserts_total += 1;
        self.ops_count += 1;
        return node_idx;
    }

    pub fn get_node(self: *WasmGraphDB, node_idx: u32) ?*const memory.Node {
        self.lookups_total += 1;
        return self.node_pool.get(node_idx);
    }

    pub fn add_edge(self: *WasmGraphDB, from_id: u32, to_id: u32, weight: f32) !u32 {
        _ = weight; // Weight not directly stored in current Edge structure
        const edge = memory.Edge{
            .from = @as(u64, from_id),
            .to = @as(u64, to_id),
            .label = 0, // Default label
            .props = [_]u8{0} ** constants.data.edge_props_size,
        };
        const edge_idx = self.edge_pool.alloc(edge) catch return error.EdgePoolFull;
        self.inserts_total += 1;
        self.ops_count += 1;
        return edge_idx;
    }

    pub fn get_edge(self: *WasmGraphDB, edge_idx: u32) ?*const memory.Edge {
        self.lookups_total += 1;
        return self.edge_pool.get(edge_idx);
    }
};

// C-style exports for JavaScript interop
export fn nendb_wasm_create() *WasmGraphDB {
    // Use a global allocator - WASM has simple memory model
    const db = std.heap.page_allocator.create(WasmGraphDB) catch unreachable;
    db.* = WasmGraphDB.init();
    return db;
}

export fn nendb_wasm_destroy(db: *WasmGraphDB) void {
    db.deinit();
    std.heap.page_allocator.destroy(db);
}

export fn nendb_wasm_add_node(db: *WasmGraphDB, id: u32) u32 {
    return db.add_node(id, "") catch 0xFFFFFFFF; // Return max u32 on error
}

export fn nendb_wasm_add_edge(db: *WasmGraphDB, from_id: u32, to_id: u32, weight: f32) u32 {
    return db.add_edge(from_id, to_id, weight) catch 0xFFFFFFFF;
}

export fn nendb_wasm_get_node_count(db: *const WasmGraphDB) u32 {
    return db.get_memory_stats().nodes.used;
}

export fn nendb_wasm_get_edge_count(db: *const WasmGraphDB) u32 {
    return db.get_memory_stats().edges.used;
}

export fn nendb_wasm_get_ops_count(db: *const WasmGraphDB) u64 {
    return db.ops_count;
}

// JavaScript interop helpers
export fn nendb_wasm_version() [*:0]const u8 {
    return constants.VERSION_SHORT.ptr;
}

// Memory information for WASM host
export fn nendb_wasm_memory_usage(db: *const WasmGraphDB) u64 {
    const stats = db.get_memory_stats();
    return @as(u64, stats.nodes.used) * @sizeOf(memory.Node) +
        @as(u64, stats.edges.used) * @sizeOf(memory.Edge) +
        @as(u64, stats.embeddings.used) * @sizeOf(memory.Embedding);
}
