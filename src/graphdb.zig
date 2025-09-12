// NenDB GraphDB engine - Data-Oriented Design Implementation
// Clean version with only working DOD functionality

const std = @import("std");
pub const layout = @import("memory/layout.zig");
pub const simd = @import("memory/simd.zig");
pub const constants = @import("constants.zig");
const wal_mod = @import("wal.zig");

// Simplified but fast in-memory graph database
pub const GraphDB = struct {
    mutex: std.Thread.Mutex,
    graph_data: layout.GraphData,
    simd_processor: simd.BatchProcessor,
    ops_since_snapshot: u64 = 0,
    inserts_total: u64 = 0,
    read_seq: std.atomic.Value(u64),
    lookups_total: std.atomic.Value(u64),
    allocator: std.mem.Allocator,
    wal: wal_mod.Wal,

    // Statistics for monitoring
    pub const DBMemoryStats = struct {
        nodes: layout.Stats,
        cache_efficiency: f32,
        simd_enabled: bool,
    };

    pub const DBStats = struct {
        memory: DBMemoryStats,
        wal: wal_mod.Wal.WalStats,
        wal_health: wal_mod.Wal.WalHealth,
    };

    pub inline fn init_inplace(self: *GraphDB, allocator: std.mem.Allocator) !void {
        self.mutex = .{};
        self.graph_data = layout.GraphData.init();
        self.simd_processor = simd.BatchProcessor.init();
        self.ops_since_snapshot = 0;
        self.inserts_total = 0;
        self.read_seq = std.atomic.Value(u64).init(0);
        self.lookups_total = std.atomic.Value(u64).init(0);
        self.allocator = allocator;
        self.wal = try wal_mod.Wal.open("nendb.wal");
    }

    // Node insertion with SIMD optimization
    pub inline fn insert_node(self: *GraphDB, id: u64, kind: u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Health check
        const health = self.wal.getHealth();
        if (!health.healthy) return error.IOError;

        // Begin seqlock write section
        _ = self.read_seq.fetchAdd(1, .acq_rel);
        defer _ = self.read_seq.fetchAdd(1, .acq_rel);

        // Insert into graph data
        const slot = try self.graph_data.insertNode(id, kind);

        // Log to WAL
        try self.wal.append_insert_node_soa(id, kind);

        // Update statistics
        self.ops_since_snapshot += 1;
        self.inserts_total += 1;

        // Use SIMD processor for batch operations if available
        if (self.ops_since_snapshot % 8 == 0) {
            try self.simd_processor.process_batch(&self.graph_data);
        }

        // Maintenance
        if (self.ops_since_snapshot >= @as(u64, @intCast(constants.storage.snapshot_interval))) {
            _ = self.wal.delete_segments_keep_last(1) catch 0;
        }

        _ = slot; // Suppress unused variable warning
    }

    // Edge insertion
    pub inline fn insert_edge(self: *GraphDB, from: u64, to: u64, label: u16) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Health check
        const health = self.wal.getHealth();
        if (!health.healthy) return error.IOError;

        // Begin seqlock write section
        _ = self.read_seq.fetchAdd(1, .acq_rel);
        defer _ = self.read_seq.fetchAdd(1, .acq_rel);

        // Insert into graph data
        _ = try self.graph_data.insertEdge(from, to, label);

        // Log to WAL
        try self.wal.append_insert_edge_soa(from, to, label);

        // Update statistics
        self.ops_since_snapshot += 1;
    }

    // Fast node lookup
    pub inline fn lookup_node(self: *GraphDB, id: u64) ?u32 {
        // Seqlock read pattern
        var seq_before: u64 = undefined;
        var seq_after: u64 = undefined;
        var result: ?u32 = null;

        while (true) {
            seq_before = self.read_seq.load(.acquire);
            if (seq_before & 1 != 0) continue; // Write in progress

            result = self.graph_data.findNodeIndex(id);

            seq_after = self.read_seq.load(.acquire);
            if (seq_before == seq_after) break; // Consistent read
        }

        // Update lookup counter
        _ = self.lookups_total.fetchAdd(1, .monotonic);
        return result;
    }

    // Clean shutdown
    pub inline fn deinit(self: *GraphDB) void {
        self.wal.close();
    }

    // Get database statistics
    pub inline fn get_memory_stats(self: *const GraphDB) DBMemoryStats {
        return DBMemoryStats{
            .nodes = self.graph_data.getStats(),
            .cache_efficiency = 8.0, // SIMD factor
            .simd_enabled = true,
        };
    }

    pub inline fn get_stats(self: *const GraphDB) DBStats {
        return DBStats{
            .memory = self.get_memory_stats(),
            .wal = self.wal.getStats(),
            .wal_health = self.wal.getHealth(),
        };
    }
};
