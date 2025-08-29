// NenDB Built-in Resource Monitor
// Provides real-time resource usage information from within the database

const std = @import("std");
const time = std.time;
const mem = std.mem;
const debug = std.debug;

pub const ResourceStats = struct {
    // CPU Usage
    cpu_percent: f64,
    cpu_time_user: f64,
    cpu_time_system: f64,

    // Memory Usage
    memory_rss_mb: u64, // Resident Set Size
    memory_virtual_mb: u64, // Virtual Memory
    memory_heap_mb: u64, // Heap Memory
    memory_pools_mb: u64, // Memory Pools Usage

    // Database-specific metrics
    nodes_allocated: u64,
    edges_allocated: u64,
    embeddings_allocated: u64,
    wal_entries: u64,
    wal_size_mb: u64,

    // Performance metrics
    operations_per_second: f64,
    average_latency_ms: f64,

    // System resources
    disk_io_read_mb: u64,
    disk_io_write_mb: u64,
    network_connections: u32,

    // Timestamp
    timestamp: i64,

    pub fn init() ResourceStats {
        return ResourceStats{
            .cpu_percent = 0.0,
            .cpu_time_user = 0.0,
            .cpu_time_system = 0.0,
            .memory_rss_mb = 0,
            .memory_virtual_mb = 0,
            .memory_heap_mb = 0,
            .memory_pools_mb = 0,
            .nodes_allocated = 0,
            .edges_allocated = 0,
            .embeddings_allocated = 0,
            .wal_entries = 0,
            .wal_size_mb = 0,
            .operations_per_second = 0.0,
            .average_latency_ms = 0.0,
            .disk_io_read_mb = 0,
            .disk_io_write_mb = 0,
            .network_connections = 0,
            .timestamp = @as(i64, @intCast(time.nanoTimestamp())),
        };
    }

    pub fn format(self: ResourceStats, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("Resource Stats:\n" ++
            "  CPU: {d:.1f}% (User: {d:.2f}s, System: {d:.2f}s)\n" ++
            "  Memory: RSS: {d} MB, Virtual: {d} MB, Heap: {d} MB, Pools: {d} MB\n" ++
            "  Database: Nodes: {d}, Edges: {d}, Embeddings: {d}\n" ++
            "  WAL: {d} entries, {d} MB\n" ++
            "  Performance: {d:.0f} ops/sec, {d:.3f} ms avg latency\n" ++
            "  I/O: Read: {d} MB, Write: {d} MB\n" ++
            "  Connections: {d}\n" ++
            "  Timestamp: {d}\n", .{
            self.cpu_percent,
            self.cpu_time_user,
            self.cpu_time_system,
            self.memory_rss_mb,
            self.memory_virtual_mb,
            self.memory_heap_mb,
            self.memory_pools_mb,
            self.nodes_allocated,
            self.edges_allocated,
            self.embeddings_allocated,
            self.wal_entries,
            self.wal_size_mb,
            self.operations_per_second,
            self.average_latency_ms,
            self.disk_io_read_mb,
            self.disk_io_write_mb,
            self.network_connections,
            self.timestamp,
        });
    }
};

pub const ResourceMonitor = struct {
    allocator: mem.Allocator,
    stats_history: std.ArrayList(ResourceStats),
    max_history_size: usize,
    start_time: i64,
    operation_count: u64,
    last_operation_time: i64,
    current_stats: ResourceStats, // Store current stats

    pub fn init(allocator: mem.Allocator, max_history: usize) ResourceMonitor {
        return ResourceMonitor{
            .allocator = allocator,
            .stats_history = std.ArrayList(ResourceStats).init(allocator),
            .max_history_size = max_history,
            .start_time = @as(i64, @intCast(time.nanoTimestamp())),
            .operation_count = 0,
            .last_operation_time = @as(i64, @intCast(time.nanoTimestamp())),
            .current_stats = ResourceStats.init(),
        };
    }

    pub fn deinit(self: *ResourceMonitor) void {
        self.stats_history.deinit();
    }

    pub fn recordOperation(self: *ResourceMonitor) void {
        self.operation_count += 1;
        self.last_operation_time = @as(i64, @intCast(time.nanoTimestamp()));
    }

    pub fn getCurrentStats(self: *ResourceMonitor) ResourceStats {
        // Update current stats with latest information
        self.current_stats.cpu_percent = 0.0; // Will be updated by platform-specific code
        self.current_stats.memory_rss_mb = 0; // Will be updated by platform-specific code
        self.current_stats.memory_virtual_mb = 0; // Will be updated by platform-specific code
        self.current_stats.memory_heap_mb = 0; // Will be updated by platform-specific code

        // Get CPU usage
        if (self.getCpuUsage()) |cpu_info| {
            self.current_stats.cpu_percent = cpu_info.percent;
            self.current_stats.cpu_time_user = cpu_info.user_time;
            self.current_stats.cpu_time_system = cpu_info.system_time;
        }

        // Get memory usage
        if (self.getMemoryUsage()) |mem_info| {
            self.current_stats.memory_rss_mb = mem_info.rss_mb;
            self.current_stats.memory_virtual_mb = mem_info.virtual_mb;
            self.current_stats.memory_heap_mb = mem_info.heap_mb;
        }

        // Calculate performance metrics
        const now = @as(i64, @intCast(time.nanoTimestamp()));
        const uptime_seconds = @as(f64, @floatFromInt(now - self.start_time)) / 1_000_000_000.0;
        if (uptime_seconds > 0) {
            self.current_stats.operations_per_second = @as(f64, @floatFromInt(self.operation_count)) / uptime_seconds;
        }

        // Calculate average latency (simplified)
        if (self.operation_count > 0) {
            const total_time_ms = @as(f64, @floatFromInt(now - self.start_time)) / 1_000_000.0;
            self.current_stats.average_latency_ms = total_time_ms / @as(f64, @floatFromInt(self.operation_count));
        }

        self.current_stats.timestamp = now;

        return self.current_stats;
    }

    pub fn updateDatabaseStats(self: *ResourceMonitor, nodes: u64, edges: u64, embeddings: u64, wal_entries: u64, wal_size_mb: u64) void {
        // Update the stored current stats
        self.current_stats.nodes_allocated = nodes;
        self.current_stats.edges_allocated = edges;
        self.current_stats.embeddings_allocated = embeddings;
        self.current_stats.wal_entries = wal_entries;
        self.current_stats.wal_size_mb = wal_size_mb;

        // Add to history
        self.addToHistory(self.current_stats);
    }

    pub fn addToHistory(self: *ResourceMonitor, stats: ResourceStats) void {
        self.stats_history.append(stats) catch return;

        // Keep history size manageable
        if (self.stats_history.items.len > self.max_history_size) {
            _ = self.stats_history.orderedRemove(0);
        }
    }

    pub fn getStatsHistory(self: *ResourceMonitor) []const ResourceStats {
        return self.stats_history.items;
    }

    pub fn getAverageStats(self: *ResourceMonitor, duration_seconds: u64) ResourceStats {
        const now = @as(i64, @intCast(time.nanoTimestamp()));
        const cutoff_time = now - @as(i64, @intCast(duration_seconds * 1_000_000_000));

        var total_stats = ResourceStats.init();
        var count: u32 = 0;

        for (self.stats_history.items) |stats| {
            if (stats.timestamp >= cutoff_time) {
                total_stats.cpu_percent += stats.cpu_percent;
                total_stats.memory_rss_mb += stats.memory_rss_mb;
                total_stats.operations_per_second += stats.operations_per_second;
                count += 1;
            }
        }

        if (count > 0) {
            total_stats.cpu_percent /= @as(f64, @floatFromInt(count));
            total_stats.memory_rss_mb /= count;
            total_stats.operations_per_second /= @as(f64, @floatFromInt(count));
        }

        return total_stats;
    }

    fn getCpuUsage(_: *ResourceMonitor) ?struct { percent: f64, user_time: f64, system_time: f64 } {
        // This would use platform-specific APIs to get CPU usage
        // For now, return null to indicate not implemented
        return null;
    }

    fn getMemoryUsage(_: *ResourceMonitor) ?struct { rss_mb: u64, virtual_mb: u64, heap_mb: u64 } {
        // This would use platform-specific APIs to get memory usage
        // For now, return null to indicate not implemented
        return null;
    }

    pub fn exportStatsJson(self: *ResourceMonitor, writer: anytype) !void {
        const stats = self.getCurrentStats();

        try writer.writeAll("{\n");
        try writer.print("  \"cpu_percent\": {d},\n", .{stats.cpu_percent});
        try writer.print("  \"memory_rss_mb\": {d},\n", .{stats.memory_rss_mb});
        try writer.print("  \"memory_virtual_mb\": {d},\n", .{stats.memory_virtual_mb});
        try writer.print("  \"nodes_allocated\": {d},\n", .{stats.nodes_allocated});
        try writer.print("  \"edges_allocated\": {d},\n", .{stats.edges_allocated});
        try writer.print("  \"operations_per_second\": {d},\n", .{stats.operations_per_second});
        try writer.print("  \"average_latency_ms\": {d},\n", .{stats.average_latency_ms});
        try writer.print("  \"uptime_seconds\": {d}\n", .{@as(f64, @floatFromInt(@as(i64, @intCast(time.nanoTimestamp())) - self.start_time)) / 1_000_000_000.0});
        try writer.writeAll("}\n");
    }

    pub fn exportStatsPrometheus(self: *ResourceMonitor, writer: anytype) !void {
        const stats = self.getCurrentStats();
        const uptime = @as(f64, @floatFromInt(@as(i64, @intCast(time.nanoTimestamp())) - self.start_time)) / 1_000_000_000.0;

        try writer.print("# HELP nendb_cpu_percent CPU usage percentage\n", .{});
        try writer.print("# TYPE nendb_cpu_percent gauge\n", .{});
        try writer.print("nendb_cpu_percent {d}\n", .{stats.cpu_percent});

        try writer.print("# HELP nendb_memory_rss_mb Resident set size in MB\n", .{});
        try writer.print("# TYPE nendb_memory_rss_mb gauge\n", .{});
        try writer.print("nendb_memory_rss_mb {d}\n", .{stats.memory_rss_mb});

        try writer.print("# HELP nendb_operations_per_second Operations per second\n", .{});
        try writer.print("# TYPE nendb_operations_per_second gauge\n", .{});
        try writer.print("nendb_operations_per_second {d}\n", .{stats.operations_per_second});

        try writer.print("# HELP nendb_uptime_seconds Database uptime in seconds\n", .{});
        try writer.print("# TYPE nendb_uptime_seconds gauge\n", .{});
        try writer.print("nendb_uptime_seconds {d}\n", .{uptime});
    }
};
