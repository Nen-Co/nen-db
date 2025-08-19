// Test Resource Monitor functionality

const std = @import("std");
const ResourceMonitor = @import("monitoring").ResourceMonitor;
const ResourceStats = @import("monitoring").ResourceStats;

test "ResourceMonitor initialization" {
    var monitor = ResourceMonitor.init(std.testing.allocator, 100);
    defer monitor.deinit();
    
    // Test initial state
    try std.testing.expectEqual(@as(u64, 0), monitor.operation_count);
    try std.testing.expectEqual(@as(usize, 0), monitor.stats_history.items.len);
}

test "ResourceMonitor operation recording" {
    var monitor = ResourceMonitor.init(std.testing.allocator, 100);
    defer monitor.deinit();
    
    // Record some operations
    monitor.recordOperation();
    monitor.recordOperation();
    monitor.recordOperation();
    
    try std.testing.expectEqual(@as(u64, 3), monitor.operation_count);
}

test "ResourceStats initialization" {
    const stats = ResourceStats.init();
    
    // Test default values
    try std.testing.expectEqual(@as(f64, 0.0), stats.cpu_percent);
    try std.testing.expectEqual(@as(u64, 0), stats.memory_rss_mb);
    try std.testing.expectEqual(@as(u64, 0), stats.nodes_allocated);
}

test "ResourceMonitor stats history" {
    var monitor = ResourceMonitor.init(std.testing.allocator, 3); // Small history for testing
    defer monitor.deinit();
    
    // Add some stats
    var stats1 = ResourceStats.init();
    stats1.cpu_percent = 10.0;
    stats1.memory_rss_mb = 100;
    
    var stats2 = ResourceStats.init();
    stats2.cpu_percent = 20.0;
    stats2.memory_rss_mb = 200;
    
    var stats3 = ResourceStats.init();
    stats3.cpu_percent = 30.0;
    stats3.memory_rss_mb = 300;
    
    var stats4 = ResourceStats.init();
    stats4.cpu_percent = 40.0;
    stats4.memory_rss_mb = 400;
    
    monitor.addToHistory(stats1);
    monitor.addToHistory(stats2);
    monitor.addToHistory(stats3);
    monitor.addToHistory(stats4); // This should remove the first one
    
    // Should only keep 3 entries
    try std.testing.expectEqual(@as(usize, 3), monitor.stats_history.items.len);
    
    // First entry should be stats2 (stats1 was removed)
    try std.testing.expectEqual(@as(f64, 20.0), monitor.stats_history.items[0].cpu_percent);
}

test "ResourceMonitor average stats" {
    var monitor = ResourceMonitor.init(std.testing.allocator, 100);
    defer monitor.deinit();
    
    // Add some stats with known values
    var stats1 = ResourceStats.init();
    stats1.cpu_percent = 10.0;
    stats1.memory_rss_mb = 100;
    stats1.operations_per_second = 100.0;
    
    var stats2 = ResourceStats.init();
    stats2.cpu_percent = 20.0;
    stats2.memory_rss_mb = 200;
    stats2.operations_per_second = 200.0;
    
    var stats3 = ResourceStats.init();
    stats3.cpu_percent = 30.0;
    stats3.memory_rss_mb = 300;
    stats3.operations_per_second = 300.0;
    
    monitor.addToHistory(stats1);
    monitor.addToHistory(stats2);
    monitor.addToHistory(stats3);
    
    // Get average stats
    const avg_stats = monitor.getAverageStats(3600); // 1 hour window
    
    // Should be average of all three
    try std.testing.expectEqual(@as(f64, 20.0), avg_stats.cpu_percent);
    try std.testing.expectEqual(@as(u64, 200), avg_stats.memory_rss_mb);
    try std.testing.expectEqual(@as(f64, 200.0), avg_stats.operations_per_second);
}

test "ResourceMonitor database stats update" {
    var monitor = ResourceMonitor.init(std.testing.allocator, 100);
    defer monitor.deinit();
    
    // Update database stats
    monitor.updateDatabaseStats(1000, 500, 200, 150, 25);
    
    // Get current stats
    const stats = monitor.getCurrentStats();
    
    try std.testing.expectEqual(@as(u64, 1000), stats.nodes_allocated);
    try std.testing.expectEqual(@as(u64, 500), stats.edges_allocated);
    try std.testing.expectEqual(@as(u64, 200), stats.embeddings_allocated);
    try std.testing.expectEqual(@as(u64, 150), stats.wal_entries);
    try std.testing.expectEqual(@as(u64, 25), stats.wal_size_mb);
}

test "ResourceMonitor JSON export" {
    var monitor = ResourceMonitor.init(std.testing.allocator, 100);
    defer monitor.deinit();
    
    // Record some operations
    monitor.recordOperation();
    monitor.recordOperation();
    
    // Update database stats
    monitor.updateDatabaseStats(100, 50, 25, 10, 5);
    
    // Test JSON export
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    try monitor.exportStatsJson(stream.writer());
    
    const json_output = stream.getWritten();
    
    // Should contain expected fields
    try std.testing.expect(std.mem.indexOf(u8, json_output, "cpu_percent") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_output, "memory_rss_mb") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_output, "nodes_allocated") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_output, "operations_per_second") != null);
}

test "ResourceMonitor Prometheus export" {
    var monitor = ResourceMonitor.init(std.testing.allocator, 100);
    defer monitor.deinit();
    
    // Record some operations
    monitor.recordOperation();
    
    // Test Prometheus export
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);
    try monitor.exportStatsPrometheus(stream.writer());
    
    const prometheus_output = stream.getWritten();
    
    // Should contain expected Prometheus format
    try std.testing.expect(std.mem.indexOf(u8, prometheus_output, "# HELP") != null);
    try std.testing.expect(std.mem.indexOf(u8, prometheus_output, "# TYPE") != null);
    try std.testing.expect(std.mem.indexOf(u8, prometheus_output, "nendb_cpu_percent") != null);
    try std.testing.expect(std.mem.indexOf(u8, prometheus_output, "nendb_memory_rss_mb") != null);
}
