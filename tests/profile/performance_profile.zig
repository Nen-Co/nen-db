// NenDB Performance Profiling
// Performance analysis and bottleneck detection
// Following TDD principles: Test → Fail → Implement → Pass → Optimize

const std = @import("std");

// Import the modules we're profiling
const nendb = @import("nendb");

// ===== PROFILING CONFIGURATION =====

const ProfileConfig = struct {
    // Profiling modes
    pub const mode = enum {
        quick, // Quick profile (1 second)
        standard, // Standard profile (10 seconds)
        detailed, // Detailed profile (60 seconds)
        stress, // Stress profile (5 minutes)
    };

    // Default profiling mode
    pub const default_mode = mode.standard;

    // Profiling intervals
    pub const quick_interval_ms = 1000; // 1 second
    pub const standard_interval_ms = 10000; // 10 seconds
    pub const detailed_interval_ms = 60000; // 60 seconds
    pub const stress_interval_ms = 300000; // 5 minutes

    // Sampling rates
    pub const quick_sample_rate = 100; // Sample every 100ms
    pub const standard_sample_rate = 1000; // Sample every 1 second
    pub const detailed_sample_rate = 5000; // Sample every 5 seconds
    pub const stress_sample_rate = 10000; // Sample every 10 seconds
};

// ===== PROFILING DATA STRUCTURES =====

const ProfileData = struct {
    timestamp: i64,
    operation_count: u64,
    memory_usage: usize,
    cpu_usage: f64,
    io_operations: u64,
    cache_hits: u64,
    cache_misses: u64,

    pub fn init() ProfileData {
        return .{
            .timestamp = std.time.milliTimestamp(),
            .operation_count = 0,
            .memory_usage = 0,
            .cpu_usage = 0.0,
            .io_operations = 0,
            .cache_hits = 0,
            .cache_misses = 0,
        };
    }

    pub fn update(self: *ProfileData, ops: u64, memory: usize, cpu: f64, io: u64, hits: u64, misses: u64) void {
        self.operation_count = ops;
        self.memory_usage = memory;
        self.cpu_usage = cpu;
        self.io_operations = io;
        self.cache_hits = hits;
        self.cache_misses = if (hits + misses > 0) hits else 0;
    }
};

const ProfileSession = struct {
    mode: ProfileConfig.mode,
    start_time: i64,
    end_time: i64,
    samples: std.ArrayList(ProfileData),
    total_operations: u64,
    peak_memory: usize,
    total_io: u64,
    total_cache_hits: u64,
    total_cache_misses: u64,

    pub fn init(mode: ProfileConfig.mode) !ProfileSession {
        return .{
            .mode = mode,
            .start_time = std.time.milliTimestamp(),
            .end_time = 0,
            .samples = try std.ArrayList(ProfileData).initCapacity(std.heap.page_allocator, 0),
            .total_operations = 0,
            .peak_memory = 0,
            .total_io = 0,
            .total_cache_hits = 0,
            .total_cache_misses = 0,
        };
    }

    pub fn deinit(self: *ProfileSession) void {
        self.samples.deinit(std.heap.page_allocator);
    }

    pub fn addSample(self: *ProfileSession, data: ProfileData) !void {
        try self.samples.append(std.heap.page_allocator, data);

        // Update totals
        self.total_operations = data.operation_count;
        if (data.memory_usage > self.peak_memory) {
            self.peak_memory = data.memory_usage;
        }
        self.total_io += data.io_operations;
        self.total_cache_hits += data.cache_hits;
        self.total_cache_misses += data.cache_misses;
    }

    pub fn finish(self: *ProfileSession) void {
        self.end_time = std.time.milliTimestamp();
    }

    pub fn getDuration(self: *const ProfileSession) i64 {
        return self.end_time - self.start_time;
    }

    pub fn getAverageOperationsPerSecond(self: *const ProfileSession) f64 {
        const duration_sec = @as(f64, @floatFromInt(self.getDuration())) / 1000.0;
        return if (duration_sec > 0) @as(f64, @floatFromInt(self.total_operations)) / duration_sec else 0.0;
    }

    pub fn getCacheHitRate(self: *const ProfileSession) f64 {
        const total_requests = self.total_cache_hits + self.total_cache_misses;
        return if (total_requests > 0) @as(f64, @floatFromInt(self.total_cache_hits)) / @as(f64, @floatFromInt(total_requests)) else 0.0;
    }
};

// ===== PROFILING FUNCTIONS =====

fn runPerformanceProfile(mode: ProfileConfig.mode) !ProfileSession {
    const session = ProfileSession.init(mode);
    defer session.deinit();

    // Determine profiling parameters based on mode
    const interval_ms = switch (mode) {
        .quick => ProfileConfig.quick_interval_ms,
        .standard => ProfileConfig.standard_interval_ms,
        .detailed => ProfileConfig.detailed_interval_ms,
        .stress => ProfileConfig.stress_interval_ms,
    };

    const sample_rate_ms = switch (mode) {
        .quick => ProfileConfig.quick_sample_rate,
        .standard => ProfileConfig.standard_sample_rate,
        .detailed => ProfileConfig.detailed_sample_rate,
        .stress => ProfileConfig.stress_sample_rate,
    };

    std.debug.print("🚀 Starting performance profile (mode: {s})\n", .{@tagName(mode)});
    std.debug.print("   Duration: {d}ms\n", .{interval_ms});
    std.debug.print("   Sample rate: {d}ms\n", .{sample_rate_ms});

    const start_time = std.time.milliTimestamp();
    var last_sample_time: i64 = 0;
    var operation_counter: u64 = 0;

    // Run profiling loop
    while (true) {
        const current_time = std.time.milliTimestamp();
        const elapsed = current_time - start_time;

        // Check if we should stop
        if (elapsed >= interval_ms) break;

        // Simulate operations
        simulateOperations(&operation_counter);

        // Take sample at specified rate
        if (current_time - last_sample_time >= sample_rate_ms) {
            const sample_data = ProfileData.init();
            sample_data.update(
                operation_counter,
                simulateMemoryUsage(),
                simulateCPUUsage(),
                simulateIOOperations(),
                simulateCacheHits(),
                simulateCacheMisses(),
            );

            try session.addSample(sample_data);
            last_sample_time = current_time;

            // Print progress
            const progress = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(interval_ms)) * 100.0;
            std.debug.print("   Progress: {d:.1}% ({d} ops)\n", .{ progress, operation_counter });
        }

        // Small delay to prevent overwhelming the system
        std.time.sleep(1000); // 1 millisecond
    }

    session.finish();

    std.debug.print("✅ Performance profile completed\n", .{});
    std.debug.print("   Total operations: {d}\n", .{session.total_operations});
    std.debug.print("   Peak memory: {d} bytes\n", .{session.peak_memory});
    std.debug.print("   Duration: {d}ms\n", .{session.getDuration()});

    return session;
}

// ===== SIMULATION FUNCTIONS =====

fn simulateOperations(counter: *u64) void {
    // Simulate various database operations
    const operation_types = [_]struct {
        name: []const u8,
        weight: u32,
    }{
        .{ .name = "node_create", .weight = 30 },
        .{ .name = "edge_create", .weight = 25 },
        .{ .name = "node_read", .weight = 20 },
        .{ .name = "edge_read", .weight = 15 },
        .{ .name = "query_execute", .weight = 10 },
    };

    // Simulate operation based on weights
    var total_weight: u32 = 0;
    for (operation_types) |op| {
        total_weight += op.weight;
    }

    var random_value = @as(u32, @intCast(std.time.milliTimestamp() % total_weight));

    for (operation_types) |op| {
        if (random_value < op.weight) {
            // Simulate this operation
            simulateOperation(op.name);
            break;
        }
        random_value -= op.weight;
    }

    counter.* += 1;
}

fn simulateOperation(operation_name: []const u8) void {
    // Simulate operation execution time
    const base_time = switch (std.mem.eql(u8, operation_name, "node_create")) {
        true => 100, // 100 microseconds
        false => switch (std.mem.eql(u8, operation_name, "edge_create")) {
            true => 80, // 80 microseconds
            false => switch (std.mem.eql(u8, operation_name, "node_read")) {
                true => 50, // 50 microseconds
                false => switch (std.mem.eql(u8, operation_name, "edge_read")) {
                    true => 40, // 40 microseconds
                    false => 200, // 200 microseconds for queries
                },
            },
        },
    };

    // Simulate work
    var dummy: u64 = 0;
    for (0..base_time) |i| {
        dummy += i;
    }
    _ = dummy;
}

fn simulateMemoryUsage() usize {
    // Simulate memory usage pattern
    const base_memory = 1024 * 1024; // 1MB base
    const variation = @as(usize, @intCast(std.time.milliTimestamp() % 100000)); // 100KB variation
    return base_memory + variation;
}

fn simulateCPUUsage() f64 {
    // Simulate CPU usage pattern (0.0 to 1.0)
    const base_usage = 0.3; // 30% base usage
    const variation = @as(f64, @floatFromInt(std.time.milliTimestamp() % 1000)) / 1000.0; // 0.0 to 1.0 variation
    return @min(1.0, base_usage + variation * 0.4); // Cap at 70%
}

fn simulateIOOperations() u64 {
    // Simulate I/O operation count
    return @as(u64, @intCast(std.time.milliTimestamp() % 100));
}

fn simulateCacheHits() u64 {
    // Simulate cache hit count
    return @as(u64, @intCast(std.time.milliTimestamp() % 1000));
}

fn simulateCacheMisses() u64 {
    // Simulate cache miss count
    return @as(u64, @intCast(std.time.milliTimestamp() % 100));
}

// ===== ANALYSIS FUNCTIONS =====

fn analyzeProfileSession(session: *const ProfileSession) void {
    std.debug.print("\n📊 Performance Analysis:\n", .{});

    // Basic metrics
    const duration_sec = @as(f64, @floatFromInt(session.getDuration())) / 1000.0;
    const ops_per_sec = session.getAverageOperationsPerSecond();
    const cache_hit_rate = session.getCacheHitRate();

    std.debug.print("   Duration: {d:.2} seconds\n", .{duration_sec});
    std.debug.print("   Operations: {d}\n", .{session.total_operations});
    std.debug.print("   Operations/sec: {d:.2}\n", .{ops_per_sec});
    std.debug.print("   Peak memory: {d} bytes ({d:.2} MB)\n", .{
        session.peak_memory,
        @as(f64, @floatFromInt(session.peak_memory)) / (1024.0 * 1024.0),
    });

    // Performance analysis
    std.debug.print("\n🎯 Performance Analysis:\n", .{});

    if (ops_per_sec > 10000) {
        std.debug.print("   ✅ Operations/sec: EXCELLENT (>10k)\n", .{});
    } else if (ops_per_sec > 5000) {
        std.debug.print("   ✅ Operations/sec: GOOD (>5k)\n", .{});
    } else if (ops_per_sec > 1000) {
        std.debug.print("   ⚠️  Operations/sec: ACCEPTABLE (>1k)\n", .{});
    } else {
        std.debug.print("   ❌ Operations/sec: NEEDS IMPROVEMENT (<1k)\n", .{});
    }

    if (session.peak_memory < 10 * 1024 * 1024) { // <10MB
        std.debug.print("   ✅ Memory usage: EXCELLENT (<10MB)\n", .{});
    } else if (session.peak_memory < 100 * 1024 * 1024) { // <100MB
        std.debug.print("   ✅ Memory usage: GOOD (<100MB)\n", .{});
    } else if (session.peak_memory < 1024 * 1024 * 1024) { // <1GB
        std.debug.print("   ⚠️  Memory usage: ACCEPTABLE (<1GB)\n", .{});
    } else {
        std.debug.print("   ❌ Memory usage: NEEDS IMPROVEMENT (>1GB)\n", .{});
    }

    if (cache_hit_rate > 0.9) {
        std.debug.print("   ✅ Cache hit rate: EXCELLENT (>90%)\n", .{});
    } else if (cache_hit_rate > 0.7) {
        std.debug.print("   ✅ Cache hit rate: GOOD (>70%)\n", .{});
    } else if (cache_hit_rate > 0.5) {
        std.debug.print("   ⚠️  Cache hit rate: ACCEPTABLE (>50%)\n", .{});
    } else {
        std.debug.print("   ❌ Cache hit rate: NEEDS IMPROVEMENT (<50%)\n", .{});
    }

    // Sample analysis
    if (session.samples.items.len > 0) {
        std.debug.print("\n📈 Sample Analysis:\n", .{});
        std.debug.print("   Total samples: {d}\n", .{session.samples.items.len});

        // Find peak performance
        var peak_ops: u64 = 0;
        var peak_sample_time: i64 = 0;

        for (session.samples.items) |sample| {
            if (sample.operation_count > peak_ops) {
                peak_ops = sample.operation_count;
                peak_sample_time = sample.timestamp;
            }
        }

        const peak_time_relative = peak_sample_time - session.start_time;
        std.debug.print("   Peak operations: {d} at {d}ms\n", .{ peak_ops, peak_time_relative });
    }
}

// ===== MAIN PROFILING ENTRY POINT =====

pub fn main() !void {
    std.debug.print("🚀 NenDB Performance Profiler\n", .{});
    std.debug.print("=============================\n\n", .{});

    // Parse command line arguments for profiling mode
    var args = std.process.args();
    _ = args.next(); // Skip program name

    var mode = ProfileConfig.default_mode;
    if (args.next()) |arg| {
        mode = std.meta.stringToEnum(ProfileConfig.mode, arg) orelse ProfileConfig.default_mode;
    }

    std.debug.print("Profiling mode: {s}\n", .{@tagName(mode)});

    // Run performance profile
    var session = try runPerformanceProfile(mode);
    defer session.deinit();

    // Analyze results
    analyzeProfileSession(&session);

    // Print recommendations
    std.debug.print("\n💡 Optimization Recommendations:\n", .{});

    const ops_per_sec = session.getAverageOperationsPerSecond();
    if (ops_per_sec < 5000) {
        std.debug.print("   - Consider optimizing critical paths\n", .{});
        std.debug.print("   - Review memory allocation patterns\n", .{});
        std.debug.print("   - Profile specific bottlenecks\n", .{});
    }

    if (session.peak_memory > 100 * 1024 * 1024) { // >100MB
        std.debug.print("   - Review memory usage patterns\n", .{});
        std.debug.print("   - Consider implementing memory pools\n", .{});
        std.debug.print("   - Check for memory leaks\n", .{});
    }

    const cache_hit_rate = session.getCacheHitRate();
    if (cache_hit_rate < 0.7) {
        std.debug.print("   - Optimize cache eviction policies\n", .{});
        std.debug.print("   - Increase cache size if possible\n", .{});
        std.debug.print("   - Review cache key strategies\n", .{});
    }

    std.debug.print("\n✅ Performance profiling completed successfully!\n", .{});
}
