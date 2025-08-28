// NenDB Resource Monitor CLI
// Provides command-line interface for monitoring database resources

const std = @import("std");
const ResourceMonitor = @import("resource_monitor.zig").ResourceMonitor;
const ResourceStats = @import("resource_monitor.zig").ResourceStats;
const platform = @import("platform_resources.zig");

pub const MonitorCommand = struct {
    monitor: *ResourceMonitor,
    output_format: OutputFormat,
    refresh_interval: u32, // seconds
    max_iterations: ?u32,
    header_printed: bool = false,

    pub const OutputFormat = enum {
        human,
        json,
        prometheus,
        csv,
    };

    pub fn init(monitor: *ResourceMonitor, format: OutputFormat, interval: u32, max_iter: ?u32) MonitorCommand {
        return MonitorCommand{
            .monitor = monitor,
            .output_format = format,
            .refresh_interval = interval,
            .max_iterations = max_iter,
        };
    }

    pub fn run(self: *MonitorCommand) !void {
        var iteration: u32 = 0;

        while (true) {
            // Check if we've reached max iterations
            if (self.max_iterations) |max| {
                if (iteration >= max) break;
            }

            // Get current stats
            const stats = self.monitor.getCurrentStats();

            // Output in requested format
            try self.outputStats(stats);

            // Increment iteration counter
            iteration += 1;

            // Wait for next refresh (except on last iteration)
            if (self.max_iterations == null or iteration < self.max_iterations.?) {
                try std.time.sleep(self.refresh_interval * 1_000_000_000);
            }
        }
    }

    fn outputStats(self: *MonitorCommand, stats: ResourceStats) !void {
        switch (self.output_format) {
            .human => try self.outputHuman(stats),
            .json => try self.outputJson(stats),
            .prometheus => try self.outputPrometheus(stats),
            .csv => try self.outputCsv(stats),
        }
    }

    fn outputHuman(self: *MonitorCommand, stats: ResourceStats) !void {
        const stdout = std.io.getStdOut().writer();

        // Clear screen (ANSI escape code)
        try stdout.writeAll("\x1B[2J\x1B[H");

        try stdout.print("NenDB Resource Monitor\n", .{});
        try stdout.print("======================\n\n", .{});

        // CPU Usage
        try stdout.print("CPU Usage:\n", .{});
        try stdout.print("  Current: {d:.1f}%\n", .{stats.cpu_percent});
        try stdout.print("  User Time: {d:.2f}s\n", .{stats.cpu_time_user});
        try stdout.print("  System Time: {d:.2f}s\n\n", .{stats.cpu_time_system});

        // Memory Usage
        try stdout.print("Memory Usage:\n", .{});
        try stdout.print("  RSS: {d} MB\n", .{stats.memory_rss_mb});
        try stdout.print("  Virtual: {d} MB\n", .{stats.memory_virtual_mb});
        try stdout.print("  Heap: {d} MB\n", .{stats.memory_pools_mb});
        try stdout.print("  Pools: {d} MB\n\n", .{stats.memory_pools_mb});

        // Database Stats
        try stdout.print("Database Status:\n", .{});
        try stdout.print("  Nodes: {d}\n", .{stats.nodes_allocated});
        try stdout.print("  Edges: {d}\n", .{stats.edges_allocated});
        try stdout.print("  Embeddings: {d}\n", .{stats.embeddings_allocated});
        try stdout.print("  WAL Entries: {d}\n", .{stats.wal_entries});
        try stdout.print("  WAL Size: {d} MB\n\n", .{stats.wal_size_mb});

        // Performance
        try stdout.print("Performance:\n", .{});
        try stdout.print("  Operations/sec: {d:.0f}\n", .{stats.operations_per_second});
        try stdout.print("  Avg Latency: {d:.3f} ms\n", .{stats.average_latency_ms});

        // Timestamp
        const timestamp = @as(f64, @floatFromInt(stats.timestamp)) / 1_000_000_000.0;
        try stdout.print("\nTimestamp: {d:.2f}s\n", .{timestamp});

        // Refresh info
        try stdout.print("Refresh: Every {d}s\n", .{self.refresh_interval});
        try stdout.print("Press Ctrl+C to stop\n", .{});
    }

    fn outputJson(self: *MonitorCommand, stats: ResourceStats) !void {
        const stdout = std.io.getStdOut().writer();
        try self.monitor.exportStatsJson(stdout);
    }

    fn outputPrometheus(self: *MonitorCommand, stats: ResourceStats) !void {
        const stdout = std.io.getStdOut().writer();
        try self.monitor.exportStatsPrometheus(stdout);
    }

    fn outputCsv(self: *MonitorCommand, stats: ResourceStats) !void {
        const stdout = std.io.getStdOut().writer();

        // CSV header (only on first iteration)
        if (!self.header_printed) {
            try stdout.writeAll("timestamp,cpu_percent,memory_rss_mb,memory_virtual_mb,nodes,edges,ops_per_sec,latency_ms\n");
            self.header_printed = true;
        }

        // CSV data row
        const timestamp = @as(f64, @floatFromInt(stats.timestamp)) / 1_000_000_000.0;
        try stdout.print("{d:.2f},{d:.1f},{d},{d},{d},{d},{d:.0f},{d:.3f}\n", .{
            timestamp,
            stats.cpu_percent,
            stats.memory_rss_mb,
            stats.memory_virtual_mb,
            stats.nodes_allocated,
            stats.edges_allocated,
            stats.operations_per_second,
            stats.average_latency_ms,
        });
    }
};

// Standalone resource monitor command
pub fn runResourceMonitor(allocator: std.mem.Allocator, args: []const []const u8) !void {
    var format: MonitorCommand.OutputFormat = .human;
    var interval: u32 = 1;
    var max_iterations: ?u32 = null;
    var database_path: ?[]const u8 = null;

    // Parse command line arguments
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--format") or std.mem.eql(u8, arg, "-f")) {
            if (i + 1 < args.len) {
                i += 1;
                const format_str = args[i];
                format = std.meta.stringToEnum(MonitorCommand.OutputFormat, format_str) orelse {
                    std.debug.print("Unknown format: {s}. Using 'human'.\n", .{format_str});
                    format = .human;
                };
            }
        } else if (std.mem.eql(u8, arg, "--interval") or std.mem.eql(u8, arg, "-i")) {
            if (i + 1 < args.len) {
                i += 1;
                interval = std.fmt.parseInt(u32, args[i], 10) catch 1;
            }
        } else if (std.mem.eql(u8, arg, "--iterations") or std.mem.eql(u8, arg, "-n")) {
            if (i + 1 < args.len) {
                i += 1;
                max_iterations = std.fmt.parseInt(u32, args[i], 10) catch 10;
            }
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return;
        } else if (arg[0] != '-') {
            database_path = arg;
        }
    }

    // Initialize resource monitor
    var monitor = ResourceMonitor.init(allocator, 1000); // Keep 1000 history entries
    defer monitor.deinit();

    // Initialize monitor command
    var cmd = MonitorCommand.init(&monitor, format, interval, max_iterations);

    // Run the monitor
    try cmd.run();
}

fn printUsage() void {
    const stdout = std.io.getStdOut().writer();
    stdout.writeAll("NenDB Resource Monitor\n" ++
        "Usage: nen monitor [options] [database_path]\n\n" ++
        "Options:\n" ++
        "  -f, --format FORMAT    Output format: human, json, prometheus, csv\n" ++
        "  -i, --interval SEC     Refresh interval in seconds (default: 1)\n" ++
        "  -n, --iterations NUM   Number of iterations to run\n" ++
        "  -h, --help            Show this help message\n\n" ++
        "Examples:\n" ++
        "  nen monitor                    # Monitor with default settings\n" ++
        "  nen monitor --format json     # Output in JSON format\n" ++
        "  nen monitor -i 5 -n 20       # Refresh every 5s, run 20 times\n" ++
        "  nen monitor --format csv > stats.csv  # Save to CSV file\n") catch {};
}

// Integration with main CLI
pub fn addMonitorCommand(parser: anytype) void {
    parser.addCommand("monitor", "Monitor database resource usage", runResourceMonitor);
}
