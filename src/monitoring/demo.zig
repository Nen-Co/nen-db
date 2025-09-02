// NenDB Resource Monitor Demo
// Shows how to use the built-in resource monitoring system

const std = @import("std");
const ResourceMonitor = @import("resource_monitor.zig").ResourceMonitor;
const ResourceStats = @import("resource_monitor.zig").ResourceStats;

pub fn main() !void {
    const stdout = std.Io.getStdOut().writer();

    try stdout.writeAll("🚀 NenDB Resource Monitor Demo\n");
    try stdout.writeAll("==============================\n\n");

    // Initialize resource monitor
    var monitor = ResourceMonitor.init(std.heap.page_allocator, 100);
    defer monitor.deinit();

    try stdout.writeAll("✅ Resource monitor initialized\n");
    try stdout.writeAll("📊 Starting resource monitoring demo...\n\n");

    // Simulate some database operations
    try simulateDatabaseOperations(&monitor, stdout);

    // Show final stats
    try stdout.writeAll("\n📈 Final Resource Statistics:\n");
    try stdout.writeAll("=============================\n");

    const final_stats = monitor.getCurrentStats();
    try stdout.print("CPU Usage: {d:.1}%\n", .{final_stats.cpu_percent});
    try stdout.print("Memory RSS: {d} MB\n", .{final_stats.memory_rss_mb});
    try stdout.print("Operations: {d}\n", .{monitor.operation_count});
    try stdout.print("Operations/sec: {d:.0}\n", .{final_stats.operations_per_second});
    try stdout.print("Nodes: {d}\n", .{final_stats.nodes_allocated});
    try stdout.print("Edges: {d}\n", .{final_stats.edges_allocated});
    try stdout.print("WAL Entries: {d}\n", .{final_stats.wal_entries});

    // Show history
    try stdout.writeAll("\n📚 Resource History (Last 5 entries):\n");
    try stdout.writeAll("=====================================\n");

    const history = monitor.getStatsHistory();
    const start_idx = if (history.len > 5) history.len - 5 else 0;

    for (start_idx..history.len) |i| {
        const stats = history[i];
        try stdout.print("Entry {d}: CPU {d:.1}%, Memory {d} MB, Ops {d:.0}/s\n", .{ i + 1, stats.cpu_percent, stats.memory_rss_mb, stats.operations_per_second });
    }

    // Export stats in different formats
    try stdout.writeAll("\n📤 Exporting Statistics:\n");
    try stdout.writeAll("========================\n");

    // JSON export
    try stdout.writeAll("JSON Format:\n");
    try monitor.exportStatsJson(stdout);
    try stdout.writeAll("\n");

    // Prometheus export
    try stdout.writeAll("Prometheus Format:\n");
    try monitor.exportStatsPrometheus(stdout);

    try stdout.writeAll("\n✅ Resource monitoring demo completed!\n");
}

fn simulateDatabaseOperations(monitor: *ResourceMonitor, writer: anytype) !void {
    try writer.writeAll("🔄 Simulating database operations...\n");

    // Simulate node creation
    for (0..1000) |i| {
        monitor.recordOperation();

        // Update database stats every 100 operations
        if (i % 100 == 0) {
            const nodes = i + 1;
            const edges = nodes * 2; // Assume 2 edges per node
            const embeddings = nodes / 10; // Assume 1 embedding per 10 nodes
            const wal_entries = nodes;
            const wal_size_mb = nodes / 100; // Assume 1 MB per 100 nodes

            monitor.updateDatabaseStats(nodes, edges, embeddings, wal_entries, wal_size_mb);

            try writer.print("  Created {d} nodes, {d} edges, {d} embeddings\n", .{ nodes, edges, embeddings });

            // Small delay to simulate real operations
            std.time.sleep(10 * 1_000_000); // 10ms
        }
    }

    try writer.writeAll("✅ Database operations simulation completed\n");
}
