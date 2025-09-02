// NenDB TigerBeetle-Style Batch Processing Demo
// Demonstrates the complete batch processing system with client-side batching,
// server-side LSM organization, and adaptive batching like TigerBeetle

const std = @import("std");
const nendb = @import("nendb");
const batch = @import("nendb").batch;
const client_batcher = @import("nendb").batch.client_batcher;
const server_batcher = @import("nendb").batch.server_batcher;

pub fn main() !void {
    std.debug.print("🐯 NenDB TigerBeetle-Style Batch Processing Demo\n", .{});
    std.debug.print("Complete batch processing system with client-side batching, server-side LSM, and adaptive batching\n\n", .{});

    // Initialize database
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db = try nendb.GraphDB.init_inplace(allocator);
    defer db.deinit();

    // Demo 1: Client-side automatic batching
    try demoClientSideBatching(allocator);

    // Demo 2: Server-side LSM organization
    try demoServerSideLSM(allocator, &db);

    // Demo 3: Homogeneous batching optimization
    try demoHomogeneousBatching(allocator);

    // Demo 4: Adaptive batching under different loads
    try demoAdaptiveBatching(allocator);

    // Demo 5: Performance comparison with TigerBeetle patterns
    try demoPerformanceComparison(allocator, &db);

    std.debug.print("✅ All TigerBeetle-style batch processing demos completed!\n", .{});
}

fn demoClientSideBatching(allocator: std.mem.Allocator) !void {
    std.debug.print("📦 Demo 1: Client-Side Automatic Batching\n", .{});
    std.debug.print("Automatically groups operations to reduce network overhead\n\n", .{});

    // Initialize client batcher with TigerBeetle-style configuration
    const config = client_batcher.ClientBatchConfig{
        .max_batch_size = 8192,
        .max_batch_wait_ms = 10, // 10ms max wait time
        .auto_flush_threshold = 100, // Auto-flush at 100 operations
        .enable_homogeneous_batching = true,
        .enable_adaptive_batching = true,
    };

    var client_batcher_instance = try client_batcher.ClientBatcher.init(allocator, config);
    defer client_batcher_instance.deinit();

    // Simulate client operations being added over time
    const start_time = std.time.nanoTimestamp();

    // Add operations that will be automatically batched
    for (0..1000) |i| {
        const node_data = std.mem.asBytes(&nendb.Node{
            .id = @intCast(i),
            .kind = 1,
            .props = "Auto-batched Node".*,
        });

        try client_batcher_instance.addCreateNode(node_data, 1);

        // Simulate some network delay
        if (i % 50 == 0) {
            std.time.sleep(1_000_000); // 1ms delay
        }
    }

    // Force final flush
    try client_batcher_instance.flush();

    const end_time = std.time.nanoTimestamp();
    const duration = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;

    // Get client-side statistics
    const stats = client_batcher_instance.getStats();

    std.debug.print("Client-Side Batching Results:\n", .{});
    std.debug.print("  - Operations queued: {}\n", .{stats.operations_queued});
    std.debug.print("  - Operations flushed: {}\n", .{stats.operations_flushed});
    std.debug.print("  - Flushes performed: {}\n", .{stats.flushes_performed});
    std.debug.print("  - Average batch size: {d:.1}\n", .{stats.getAverageBatchSize()});
    std.debug.print("  - Average flush time: {d:.3} ms\n", .{stats.getAverageFlushTime() / 1_000_000.0});
    std.debug.print("  - Queue utilization: {d:.1}%\n", .{stats.getQueueUtilization() * 100.0});
    std.debug.print("  - Batch size adjustments: {}\n", .{stats.batch_size_adjustments});
    std.debug.print("  - Total duration: {d:.3} seconds\n", .{duration});
    std.debug.print("\n", .{});
}

fn demoServerSideLSM(allocator: std.mem.Allocator, db: *nendb.GraphDB) !void {
    std.debug.print("🏗️ Demo 2: Server-Side LSM Organization\n", .{});
    std.debug.print("Organizes batches in LSM tree levels for high durability\n\n", .{});

    // Initialize server batcher with LSM configuration
    const config = server_batcher.ServerBatchConfig{
        .max_batch_size = 8192,
        .lsm_levels = 4,
        .level_size_multiplier = 10, // Each level 10x larger
        .compaction_threshold = 1000,
        .enable_parallel_processing = true,
        .enable_write_optimization = true,
    };

    var server_batcher_instance = try server_batcher.ServerBatcher.init(allocator, config, &db.wal);
    defer server_batcher_instance.deinit();

    // Create test batches to demonstrate LSM organization
    const num_batches = 50;
    var total_operations: u32 = 0;

    for (0..num_batches) |batch_idx| {
        var test_batch = batch.Batch.init();

        // Add operations to batch
        const batch_size = 100 + (batch_idx % 500); // Varying batch sizes
        for (0..batch_size) |op_idx| {
            const node_id = batch_idx * 1000 + op_idx;

            try test_batch.addCreateNode(.{
                .id = @intCast(node_id),
                .kind = 1,
                .props = "LSM Node".*,
            });

            if (op_idx > 0) {
                try test_batch.addCreateEdge(.{
                    .from = @intCast(node_id - 1),
                    .to = @intCast(node_id),
                    .label = 1,
                    .props = "".*,
                });
            }

            if (test_batch.isFull()) break;
        }

        // Process batch through server
        const result = try server_batcher_instance.processClientBatch(test_batch);
        total_operations += result.processed;

        if (!result.success) {
            std.debug.print("❌ Batch {} failed: {}\n", .{ batch_idx, result.err });
            return;
        }
    }

    // Get server-side statistics
    const server_stats = server_batcher_instance.getStats();
    const lsm_stats = server_batcher_instance.getLSMStats();

    std.debug.print("Server-Side LSM Results:\n", .{});
    std.debug.print("  - Batches processed: {}\n", .{server_stats.batches_processed});
    std.debug.print("  - Operations processed: {}\n", .{server_stats.operations_processed});
    std.debug.print("  - Average processing time: {d:.3} ms\n", .{server_stats.getAverageProcessingTime() / 1_000_000.0});
    std.debug.print("  - Average batch size: {d:.1}\n", .{server_stats.getAverageBatchSize()});
    std.debug.print("  - Merges performed: {}\n", .{server_stats.merges_performed});
    std.debug.print("  - Compactions performed: {}\n", .{server_stats.compactions_performed});
    std.debug.print("  - Compaction frequency: {d:.3}\n", .{server_stats.getCompactionFrequency()});

    std.debug.print("\nLSM Tree Organization:\n", .{});
    for (lsm_stats.level_sizes, 0..) |size, i| {
        std.debug.print("  - Level {}: {} operations, {} batches\n", .{ i, size, lsm_stats.level_batch_counts[i] });
    }
    std.debug.print("  - Total LSM size: {} operations\n", .{lsm_stats.getTotalSize()});
    std.debug.print("  - Total LSM batches: {}\n", .{lsm_stats.getTotalBatches()});
    std.debug.print("\n", .{});
}

fn demoHomogeneousBatching(allocator: std.mem.Allocator) !void {
    std.debug.print("🎯 Demo 3: Homogeneous Batching Optimization\n", .{});
    std.debug.print("Groups similar operations for optimal CPU processing\n\n", .{});

    const config = client_batcher.ClientBatchConfig{
        .max_batch_size = 8192,
        .max_batch_wait_ms = 5,
        .auto_flush_threshold = 50,
        .enable_homogeneous_batching = true,
        .enable_adaptive_batching = false, // Disable for this test
    };

    var client_batcher_instance = try client_batcher.ClientBatcher.init(allocator, config);
    defer client_batcher_instance.deinit();

    // Add mixed operations that will be grouped by type
    const operations_per_type = 200;

    // Add node operations
    for (0..operations_per_type) |i| {
        const node_data = std.mem.asBytes(&nendb.Node{
            .id = @intCast(i),
            .kind = 1,
            .props = "Homogeneous Node".*,
        });
        try client_batcher_instance.addCreateNode(node_data, 1);
    }

    // Add edge operations
    for (0..operations_per_type) |i| {
        const edge_data = std.mem.asBytes(&nendb.Edge{
            .from = @intCast(i),
            .to = @intCast(i + 1),
            .label = 1,
            .props = "".*,
        });
        try client_batcher_instance.addCreateEdge(edge_data, 1);
    }

    // Add vector operations
    for (0..operations_per_type) |i| {
        const embedding_data = [_]u8{0} ** 264; // 8 bytes node_id + 256 bytes vector
        std.mem.writeIntLittle(u64, embedding_data[0..8], @intCast(i));
        try client_batcher_instance.addSetEmbedding(&embedding_data, 1);
    }

    // Force flush to see homogeneous grouping
    try client_batcher_instance.flush();

    const stats = client_batcher_instance.getStats();

    std.debug.print("Homogeneous Batching Results:\n", .{});
    std.debug.print("  - Total operations: {}\n", .{stats.operations_queued});
    std.debug.print("  - Operations flushed: {}\n", .{stats.operations_flushed});
    std.debug.print("  - Flushes performed: {}\n", .{stats.flushes_performed});
    std.debug.print("  - Average batch size: {d:.1}\n", .{stats.getAverageBatchSize()});
    std.debug.print("  - Queue utilization: {d:.1}%\n", .{stats.getQueueUtilization() * 100.0});
    std.debug.print("\n", .{});
}

fn demoAdaptiveBatching(allocator: std.mem.Allocator) !void {
    std.debug.print("🔄 Demo 4: Adaptive Batching Under Different Loads\n", .{});
    std.debug.print("Automatically adjusts batch size based on system load\n\n", .{});

    const config = client_batcher.ClientBatchConfig{
        .max_batch_size = 8192,
        .max_batch_wait_ms = 10,
        .auto_flush_threshold = 100,
        .enable_homogeneous_batching = true,
        .enable_adaptive_batching = true,
    };

    var client_batcher_instance = try client_batcher.ClientBatcher.init(allocator, config);
    defer client_batcher_instance.deinit();

    // Simulate different load conditions
    const load_scenarios = [_]struct { name: []const u8, ops_per_batch: u32, delay_ms: u32 }{
        .{ .name = "Light Load", .ops_per_batch = 50, .delay_ms = 5 },
        .{ .name = "Medium Load", .ops_per_batch = 200, .delay_ms = 2 },
        .{ .name = "Heavy Load", .ops_per_batch = 500, .delay_ms = 1 },
        .{ .name = "Extreme Load", .ops_per_batch = 1000, .delay_ms = 0 },
    };

    for (load_scenarios) |scenario| {
        std.debug.print("Testing {} scenario:\n", .{scenario.name});

        // Reset statistics for this scenario
        client_batcher_instance.stats = client_batcher.ClientBatchStats.init();

        const start_time = std.time.nanoTimestamp();

        // Add operations with scenario-specific timing
        for (0..scenario.ops_per_batch * 5) |i| { // 5 batches per scenario
            const node_data = std.mem.asBytes(&nendb.Node{
                .id = @intCast(i),
                .kind = 1,
                .props = scenario.name.*,
            });

            try client_batcher_instance.addCreateNode(node_data, 1);

            // Simulate load-dependent delay
            if (scenario.delay_ms > 0) {
                std.time.sleep(scenario.delay_ms * 1_000_000);
            }
        }

        // Force final flush
        try client_batcher_instance.flush();

        const end_time = std.time.nanoTimestamp();
        const duration = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;

        const stats = client_batcher_instance.getStats();
        const current_config = client_batcher_instance.getConfig();

        std.debug.print("  - Operations: {}\n", .{stats.operations_flushed});
        std.debug.print("  - Flushes: {}\n", .{stats.flushes_performed});
        std.debug.print("  - Avg batch size: {d:.1}\n", .{stats.getAverageBatchSize()});
        std.debug.print("  - Avg flush time: {d:.3} ms\n", .{stats.getAverageFlushTime() / 1_000_000.0});
        std.debug.print("  - Batch size adjustments: {}\n", .{stats.batch_size_adjustments});
        std.debug.print("  - Current auto-flush threshold: {}\n", .{current_config.auto_flush_threshold});
        std.debug.print("  - Duration: {d:.3} seconds\n", .{duration});
        std.debug.print("\n", .{});
    }
}

fn demoPerformanceComparison(allocator: std.mem.Allocator, db: *nendb.GraphDB) !void {
    std.debug.print("🏁 Demo 5: Performance Comparison with TigerBeetle Patterns\n", .{});
    std.debug.print("Comparing different batching approaches\n\n", .{});

    const num_operations = 10000;

    // Test 1: Individual operations (baseline)
    const individual_start = std.time.nanoTimestamp();
    for (0..num_operations) |i| {
        try db.insert_node(.{
            .id = @intCast(100000 + i),
            .kind = 1,
            .props = "Individual".*,
        });
    }
    const individual_end = std.time.nanoTimestamp();
    const individual_duration = @as(f64, @floatFromInt(individual_end - individual_start)) / 1_000_000_000.0;

    // Test 2: Manual batching (our original approach)
    const manual_start = std.time.nanoTimestamp();
    var batch_count: u32 = 0;
    while (batch_count < num_operations / 1000) : (batch_count += 1) {
        var manual_batch = batch.Batch.init();

        for (0..1000) |i| {
            try manual_batch.addCreateNode(.{
                .id = @intCast(200000 + batch_count * 1000 + i),
                .kind = 1,
                .props = "Manual".*,
            });

            if (manual_batch.isFull()) break;
        }

        var batch_api = batch.BatchAPI.init(&db.node_pool, &db.edge_pool, &db.wal);
        _ = try batch_api.executeBatch(&manual_batch);
    }
    const manual_end = std.time.nanoTimestamp();
    const manual_duration = @as(f64, @floatFromInt(manual_end - manual_start)) / 1_000_000_000.0;

    // Test 3: TigerBeetle-style client-side batching
    const client_config = client_batcher.ClientBatchConfig{
        .max_batch_size = 8192,
        .max_batch_wait_ms = 1,
        .auto_flush_threshold = 1000,
        .enable_homogeneous_batching = true,
        .enable_adaptive_batching = true,
    };

    var client_batcher_instance = try client_batcher.ClientBatcher.init(allocator, client_config);
    defer client_batcher_instance.deinit();

    const client_start = std.time.nanoTimestamp();
    for (0..num_operations) |i| {
        const node_data = std.mem.asBytes(&nendb.Node{
            .id = @intCast(300000 + i),
            .kind = 1,
            .props = "TigerBeetle".*,
        });
        try client_batcher_instance.addCreateNode(node_data, 1);
    }
    try client_batcher_instance.flush();
    const client_end = std.time.nanoTimestamp();
    const client_duration = @as(f64, @floatFromInt(client_end - client_start)) / 1_000_000_000.0;

    // Test 4: TigerBeetle-style server-side LSM processing
    const server_config = server_batcher.ServerBatchConfig{
        .max_batch_size = 8192,
        .lsm_levels = 4,
        .level_size_multiplier = 10,
        .compaction_threshold = 1000,
        .enable_parallel_processing = true,
        .enable_write_optimization = true,
    };

    var server_batcher_instance = try server_batcher.ServerBatcher.init(allocator, server_config, &db.wal);
    defer server_batcher_instance.deinit();

    const server_start = std.time.nanoTimestamp();
    var server_batch_count: u32 = 0;
    while (server_batch_count < num_operations / 1000) : (server_batch_count += 1) {
        var server_batch = batch.Batch.init();

        for (0..1000) |i| {
            try server_batch.addCreateNode(.{
                .id = @intCast(400000 + server_batch_count * 1000 + i),
                .kind = 1,
                .props = "LSM".*,
            });

            if (server_batch.isFull()) break;
        }

        _ = try server_batcher_instance.processClientBatch(server_batch);
    }
    const server_end = std.time.nanoTimestamp();
    const server_duration = @as(f64, @floatFromInt(server_end - server_start)) / 1_000_000_000.0;

    // Calculate performance metrics
    const individual_ops_per_sec = @as(f64, @floatFromInt(num_operations)) / individual_duration;
    const manual_ops_per_sec = @as(f64, @floatFromInt(num_operations)) / manual_duration;
    const client_ops_per_sec = @as(f64, @floatFromInt(num_operations)) / client_duration;
    const server_ops_per_sec = @as(f64, @floatFromInt(num_operations)) / server_duration;

    std.debug.print("Performance Comparison Results ({} operations):\n", .{num_operations});
    std.debug.print("  - Individual operations: {d:.0} ops/sec ({d:.3}s)\n", .{ individual_ops_per_sec, individual_duration });
    std.debug.print("  - Manual batching: {d:.0} ops/sec ({d:.3}s) - {d:.1}x faster\n", .{ manual_ops_per_sec, manual_duration, manual_ops_per_sec / individual_ops_per_sec });
    std.debug.print("  - Client-side batching: {d:.0} ops/sec ({d:.3}s) - {d:.1}x faster\n", .{ client_ops_per_sec, client_duration, client_ops_per_sec / individual_ops_per_sec });
    std.debug.print("  - Server-side LSM: {d:.0} ops/sec ({d:.3}s) - {d:.1}x faster\n", .{ server_ops_per_sec, server_duration, server_ops_per_sec / individual_ops_per_sec });

    const client_stats = client_batcher_instance.getStats();
    const server_stats = server_batcher_instance.getStats();

    std.debug.print("\nTigerBeetle-Style Optimizations:\n", .{});
    std.debug.print("  - Client-side avg batch size: {d:.1}\n", .{client_stats.getAverageBatchSize()});
    std.debug.print("  - Client-side avg flush time: {d:.3} ms\n", .{client_stats.getAverageFlushTime() / 1_000_000.0});
    std.debug.print("  - Server-side merges: {}\n", .{server_stats.merges_performed});
    std.debug.print("  - Server-side compactions: {}\n", .{server_stats.compactions_performed});
    std.debug.print("  - Server-side avg processing time: {d:.3} ms\n", .{server_stats.getAverageProcessingTime() / 1_000_000.0});
    std.debug.print("\n", .{});
}
