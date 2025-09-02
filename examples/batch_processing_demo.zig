// NenDB Batch Processing Demo
// Demonstrates TigerBeetle-style batch processing for high-performance operations

const std = @import("std");
const nendb = @import("nendb");
const batch = @import("nendb").batch;

pub fn main() !void {
    std.debug.print("🚀 NenDB Batch Processing Demo\n", .{});
    std.debug.print("Inspired by TigerBeetle's high-performance batching\n\n", .{});

    // Initialize database with batch processing
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db = try nendb.GraphDB.init_inplace(allocator);
    defer db.deinit();

    // Initialize batch API
    var batch_api = batch.BatchAPI.init(&db.node_pool, &db.edge_pool, &db.wal);
    
    // Demo 1: Basic batch operations
    try demoBasicBatching(&batch_api);
    
    // Demo 2: High-performance bulk insert
    try demoBulkInsert(&batch_api);
    
    // Demo 3: Mixed operations in single batch
    try demoMixedOperations(&batch_api);
    
    // Demo 4: Batch statistics and monitoring
    try demoBatchStatistics(&batch_api);
    
    std.debug.print("✅ All batch processing demos completed successfully!\n", .{});
}

fn demoBasicBatching(batch_api: *batch.BatchAPI) !void {
    std.debug.print("📦 Demo 1: Basic Batch Operations\n", .{});
    
    var batch1 = batch.Batch.init();
    
    // Add multiple nodes to batch
    try batch1.addCreateNode(.{
        .id = 1,
        .kind = 1, // User type
        .props = "Alice".*,
    });
    
    try batch1.addCreateNode(.{
        .id = 2,
        .kind = 1, // User type
        .props = "Bob".*,
    });
    
    try batch1.addCreateNode(.{
        .id = 3,
        .kind = 1, // User type
        .props = "Charlie".*,
    });
    
    // Add edges to batch
    try batch1.addCreateEdge(.{
        .from = 1,
        .to = 2,
        .label = 1, // FRIENDS_WITH
        .props = "".*,
    });
    
    try batch1.addCreateEdge(.{
        .from = 2,
        .to = 3,
        .label = 1, // FRIENDS_WITH
        .props = "".*,
    });
    
    // Execute batch atomically
    const result = try batch_api.executeBatch(&batch1);
    
    if (result.success) {
        std.debug.print("✅ Batch processed successfully: {} operations\n", .{result.processed});
    } else {
        std.debug.print("❌ Batch failed: {}\n", .{result.err});
    }
    
    std.debug.print("\n", .{});
}

fn demoBulkInsert(batch_api: *batch.BatchAPI) !void {
    std.debug.print("⚡ Demo 2: High-Performance Bulk Insert\n", .{});
    
    const start_time = std.time.nanoTimestamp();
    
    // Create multiple batches for bulk insert
    var batch_count: u32 = 0;
    var total_operations: u32 = 0;
    
    while (batch_count < 10) : (batch_count += 1) {
        var current_batch = batch.Batch.init();
        var operation_count: u32 = 0;
        
        // Fill batch with operations
        while (operation_count < 1000) : (operation_count += 1) {
            const node_id = batch_count * 1000 + operation_count;
            
            try current_batch.addCreateNode(.{
                .id = node_id,
                .kind = 1,
                .props = "Bulk Node".*,
            });
            
            // Add some edges
            if (operation_count > 0) {
                try current_batch.addCreateEdge(.{
                    .from = node_id - 1,
                    .to = node_id,
                    .label = 1,
                    .props = "".*,
                });
            }
            
            // Check if batch is full
            if (current_batch.isFull()) break;
        }
        
        // Execute batch
        const result = try batch_api.executeBatch(&current_batch);
        if (result.success) {
            total_operations += result.processed;
        } else {
            if (result.err) |err| {
                std.debug.print("❌ Batch {} failed: {}\n", .{batch_count, @errorName(err)});
            } else {
                std.debug.print("❌ Batch {} failed: unknown error\n", .{batch_count});
            }
            return;
        }
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;
    const ops_per_second = @as(f64, @floatFromInt(total_operations)) / duration;
    
    std.debug.print("✅ Bulk insert completed:\n", .{});
    std.debug.print("   - Total operations: {}\n", .{total_operations});
    std.debug.print("   - Duration: {d:.3} seconds\n", .{duration});
    std.debug.print("   - Throughput: {d:.0} ops/sec\n", .{ops_per_second});
    std.debug.print("\n", .{});
}

fn demoMixedOperations(batch_api: *batch.BatchAPI) !void {
    std.debug.print("🔄 Demo 3: Mixed Operations in Single Batch\n", .{});
    
    var mixed_batch = batch.Batch.init();
    
    // Add nodes
    try mixed_batch.addCreateNode(.{
        .id = 100,
        .kind = 2, // Post type
        .props = "First Post".*,
    });
    
    try mixed_batch.addCreateNode(.{
        .id = 101,
        .kind = 2, // Post type
        .props = "Second Post".*,
    });
    
    // Add edges
    try mixed_batch.addCreateEdge(.{
        .from = 1, // Alice
        .to = 100,
        .label = 2, // AUTHORED
        .props = "".*,
    });
    
    try mixed_batch.addCreateEdge(.{
        .from = 2, // Bob
        .to = 101,
        .label = 2, // AUTHORED
        .props = "".*,
    });
    
    // Add vector embeddings
    const embedding1 = [_]f32{ 0.1, 0.2, 0.3, 0.4, 0.5 } ++ [_]f32{0} ** 251;
    try mixed_batch.addSetEmbedding(100, embedding1);
    
    const embedding2 = [_]f32{ 0.2, 0.3, 0.4, 0.5, 0.6 } ++ [_]f32{0} ** 251;
    try mixed_batch.addSetEmbedding(101, embedding2);
    
    // Execute mixed batch
    const result = try batch_api.executeBatch(&mixed_batch);
    
    if (result.success) {
        std.debug.print("✅ Mixed batch processed: {} operations\n", .{result.processed});
        std.debug.print("   - Nodes created: 2\n", .{});
        std.debug.print("   - Edges created: 2\n", .{});
        std.debug.print("   - Embeddings set: 2\n", .{});
    } else {
        if (result.err) |err| {
            std.debug.print("❌ Mixed batch failed: {}\n", .{@errorName(err)});
        } else {
            std.debug.print("❌ Mixed batch failed: unknown error\n", .{});
        }
    }
    
    std.debug.print("\n", .{});
}

fn demoBatchStatistics(batch_api: *batch.BatchAPI) !void {
    std.debug.print("📊 Demo 4: Batch Statistics and Monitoring\n", .{});
    
    const stats = batch_api.getStats();
    
    std.debug.print("Batch Processing Statistics:\n", .{});
    std.debug.print("   - Batches processed: {}\n", .{stats.batches_processed});
    std.debug.print("   - Messages processed: {}\n", .{stats.messages_processed});
    std.debug.print("   - Batches failed: {}\n", .{stats.batches_failed});
    std.debug.print("   - Average batch size: {d:.1}\n", .{stats.avg_batch_size});
    
    if (stats.batches_processed > 0) {
        const avg_processing_time = @as(f64, @floatFromInt(stats.total_processing_time)) / 
                                   @as(f64, @floatFromInt(stats.batches_processed)) / 1_000_000.0;
        std.debug.print("   - Average processing time: {d:.3} ms\n", .{avg_processing_time});
    }
    
    const success_rate = if (stats.batches_processed > 0)
        @as(f64, @floatFromInt(stats.batches_processed)) / 
        @as(f64, @floatFromInt(stats.batches_processed + stats.batches_failed)) * 100.0
    else
        0.0;
    
    std.debug.print("   - Success rate: {d:.1}%\n", .{success_rate});
    std.debug.print("\n", .{});
}

// Performance comparison: Batch vs Individual Operations
fn comparePerformance(db: *nendb.GraphDB, batch_api: *batch.BatchAPI) !void {
    std.debug.print("🏁 Performance Comparison: Batch vs Individual Operations\n", .{});
    
    const num_operations = 10000;
    
    // Test individual operations
    const individual_start = std.time.nanoTimestamp();
    var i: u32 = 0;
    while (i < num_operations) : (i += 1) {
        try db.createNode(.{
            .id = 10000 + i,
            .kind = 1,
            .props = "Individual".*,
        });
    }
    const individual_end = std.time.nanoTimestamp();
    const individual_duration = @as(f64, @floatFromInt(individual_end - individual_start)) / 1_000_000_000.0;
    
    // Test batch operations
    const batch_start = std.time.nanoTimestamp();
    var batch_count: u32 = 0;
    while (batch_count < num_operations / 1000) : (batch_count += 1) {
        var current_batch = batch.Batch.init();
        var j: u32 = 0;
        while (j < 1000) : (j += 1) {
            try current_batch.addCreateNode(.{
                .id = 20000 + batch_count * 1000 + j,
                .kind = 1,
                .props = "Batch".*,
            });
        }
        _ = try batch_api.executeBatch(&current_batch);
    }
    const batch_end = std.time.nanoTimestamp();
    const batch_duration = @as(f64, @floatFromInt(batch_end - batch_start)) / 1_000_000_000.0;
    
    std.debug.print("Results for {} operations:\n", .{num_operations});
    std.debug.print("   - Individual operations: {d:.3} seconds\n", .{individual_duration});
    std.debug.print("   - Batch operations: {d:.3} seconds\n", .{batch_duration});
    
    const speedup = individual_duration / batch_duration;
    std.debug.print("   - Speedup: {d:.1}x faster with batching\n", .{speedup});
    std.debug.print("\n", .{});
}
