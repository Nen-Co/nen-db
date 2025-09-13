// NenDB WASM Library - Browser/Embedded Compatible Version with DOD
// Updated to use DOD layout for optimal WASM performance

const std = @import("std");
const layout = @import("memory/layout.zig");
const constants = @import("constants.zig");

// Memory types for compatibility with existing WASM API
const Node = struct {
    id: u64,
    value: f64,
};

const Edge = struct {
    from: u64,
    to: u64,
    weight: f64,
};

const Embedding = struct {
    node_id: u64,
    vector: [constants.data.embedding_dimensions]f32,
};

// WASM entry point (required by Zig WASM)
pub fn main() void {
    // WASM library doesn't need a main function, just export the C API
}

// DOD-optimized WASM memory structures
const DODWasmMemory = struct {
    const MAX_NODES = 10_000; // Reduced for WASM constraints
    const MAX_EDGES = 50_000;
    const BATCH_SIZE = 4; // Smaller batches for WASM

    // Struct of Arrays for cache efficiency in WASM
    node_ids: [MAX_NODES]u32 align(32),
    node_values: [MAX_NODES]f64 align(32),
    edge_from: [MAX_EDGES]u32 align(32),
    edge_to: [MAX_EDGES]u32 align(32),
    edge_weights: [MAX_EDGES]f64 align(32),
    node_count: u32 = 0,
    edge_count: u32 = 0,
};

// WASM-compatible GraphDB that operates entirely in-memory
pub const WasmGraphDB = struct {
    // DOD layout for optimal WASM performance
    graph_data: layout.GraphData align(64),
    dod_memory: DODWasmMemory align(64),

    // No WAL, no filesystem - pure in-memory operation
    ops_count: u64 = 0,
    inserts_total: u64 = 0,
    lookups_total: u64 = 0,

    pub const WasmMemoryStats = struct {
        node_count: u32,
        edge_count: u32,
        memory_usage_bytes: usize,
        max_nodes: u32,
        max_edges: u32,
    };

    pub fn init() WasmGraphDB {
        return WasmGraphDB{
            .graph_data = layout.GraphData.init(),
            .dod_memory = DODWasmMemory{
                .node_ids = [_]u32{0} ** DODWasmMemory.MAX_NODES,
                .node_values = [_]f64{0.0} ** DODWasmMemory.MAX_NODES,
                .edge_from = [_]u32{0} ** DODWasmMemory.MAX_EDGES,
                .edge_to = [_]u32{0} ** DODWasmMemory.MAX_EDGES,
                .edge_weights = [_]f64{0.0} ** DODWasmMemory.MAX_EDGES,
            },
        };
    }

    pub fn deinit(self: *WasmGraphDB) void {
        // Static pools don't need deinitialization in WASM
        _ = self;
    }

    pub fn get_memory_stats(self: *const WasmGraphDB) WasmMemoryStats {
        return WasmMemoryStats{
            .node_count = self.dod_memory.node_count,
            .edge_count = self.dod_memory.edge_count,
            .memory_usage_bytes = @sizeOf(DODWasmMemory),
            .max_nodes = DODWasmMemory.MAX_NODES,
            .max_edges = DODWasmMemory.MAX_EDGES,
        };
    }

    pub fn add_node(self: *WasmGraphDB, id: u32, properties: []const u8) !u32 {
        _ = properties; // TODO: Process properties with DOD approach

        if (self.dod_memory.node_count >= DODWasmMemory.MAX_NODES) {
            return error.NodePoolFull;
        }

        const node_idx = self.dod_memory.node_count;
        self.dod_memory.node_ids[node_idx] = id;
        self.dod_memory.node_values[node_idx] = 0.0; // Default value
        self.dod_memory.node_count += 1;

        self.inserts_total += 1;
        self.ops_count += 1;
        return node_idx;
    }

    pub fn get_node(self: *WasmGraphDB, node_idx: u32) ?struct { id: u32, value: f64 } {
        self.lookups_total += 1;
        if (node_idx >= self.dod_memory.node_count) return null;

        return .{
            .id = self.dod_memory.node_ids[node_idx],
            .value = self.dod_memory.node_values[node_idx],
        };
    }

    pub fn add_edge(self: *WasmGraphDB, from_id: u32, to_id: u32, weight: f64) !u32 {
        if (self.dod_memory.edge_count >= DODWasmMemory.MAX_EDGES) {
            return error.EdgePoolFull;
        }

        const edge_idx = self.dod_memory.edge_count;
        self.dod_memory.edge_from[edge_idx] = from_id;
        self.dod_memory.edge_to[edge_idx] = to_id;
        self.dod_memory.edge_weights[edge_idx] = weight;
        self.dod_memory.edge_count += 1;

        self.inserts_total += 1;
        self.ops_count += 1;
        return edge_idx;
    }

    pub fn get_edge(self: *WasmGraphDB, edge_idx: u32) ?struct { from: u32, to: u32, weight: f64 } {
        self.lookups_total += 1;
        if (edge_idx >= self.dod_memory.edge_count) return null;

        return .{
            .from = self.dod_memory.edge_from[edge_idx],
            .to = self.dod_memory.edge_to[edge_idx],
            .weight = self.dod_memory.edge_weights[edge_idx],
        };
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
    return db.add_edge(from_id, to_id, @floatCast(weight)) catch 0xFFFFFFFF;
}

export fn nendb_wasm_get_node_count(db: *const WasmGraphDB) u32 {
    return db.get_memory_stats().node_count;
}

export fn nendb_wasm_get_edge_count(db: *const WasmGraphDB) u32 {
    return db.get_memory_stats().edge_count;
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
    return stats.memory_usage_bytes;
}
