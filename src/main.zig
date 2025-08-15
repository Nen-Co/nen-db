// NenDB CLI - Command Line Interface
// Simple CLI for interacting with NenDB

const std = @import("std");
const nendb = @import("lib.zig");
const posix = std.posix;

var shutdown_flag: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
fn on_signal(sig: c_int) callconv(.C) void {
    _ = sig;
    shutdown_flag.store(true, .release);
}

pub fn main() !void {
    std.debug.print("NenDB Production Start (TigerBeetle-style)\n", .{});
    std.debug.print("Version: 1.0.0 | Zig: {s}\n", .{@import("builtin").zig_version_string});

    // Start TCP server if requested
    const server = @import("api/server.zig");
    var it = std.process.args();
    _ = it.next(); // skip program name
    var db_path: []const u8 = ".";
    var command: []const u8 = "up"; // default command
    if (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "serve")) {
            try server.start_server(5454);
            return;
        } else if (std.mem.eql(u8, arg, "up")) {
            command = "up";
            if (it.next()) |path| db_path = path;
        } else if (std.mem.eql(u8, arg, "init")) {
            command = "init";
            if (it.next()) |path| db_path = path;
        } else if (std.mem.eql(u8, arg, "status")) {
            command = "status";
            if (it.next()) |path| db_path = path;
        } else if (std.mem.eql(u8, arg, "snapshot")) {
            command = "snapshot";
            if (it.next()) |path| db_path = path;
        } else if (std.mem.eql(u8, arg, "restore")) {
            command = "restore";
            if (it.next()) |path| db_path = path;
        } else if (std.mem.eql(u8, arg, "check")) {
            command = "check";
            if (it.next()) |path| db_path = path;
        } else if (std.mem.eql(u8, arg, "compact")) {
            command = "compact";
            if (it.next()) |path| db_path = path;
        } else if (std.mem.eql(u8, arg, "force-unlock")) {
            command = "force-unlock";
            if (it.next()) |path| db_path = path;
        } else {
            // Treat first arg as a path, default command remains 'up'
            db_path = arg;
        }
    }
    if (std.mem.eql(u8, command, "status")) {
        const GraphDB = @import("graphdb.zig").GraphDB;
        var db: GraphDB = undefined;
        // Read-only open so status can run while the writer holds the lock
        try GraphDB.open_read_only(&db, db_path);
        defer db.deinit();
        const stats = db.get_stats();
        const next = std.process.args(); // quick flag scan for --json and --fail-on-unhealthy
        var is_json = false;
        var fail_on_unhealthy = false;
        var it2 = next;
        while (it2.next()) |a| {
            if (std.mem.eql(u8, a, "--json")) {
                is_json = true;
            } else if (std.mem.eql(u8, a, "--fail-on-unhealthy")) {
                fail_on_unhealthy = true;
            }
        }
        if (is_json) {
            std.debug.print("{{\n  \"path\": \"{s}\",\n  \"memory\": {{\n    \"nodes\": {{\"used\": {d}, \"free\": {d}, \"capacity\": {d}}},\n    \"edges\": {{\"used\": {d}, \"free\": {d}, \"capacity\": {d}}},\n    \"embeddings\": {{\"used\": {d}, \"free\": {d}, \"capacity\": {d}}}\n  }},\n  \"wal\": {{\n    \"entries_written\": {d},\n    \"entries_replayed\": {d},\n    \"truncations\": {d},\n    \"bytes_written\": {d}\n  }},\n  \"wal_health\": {{\n    \"healthy\": {s},\n    \"io_error_count\": {d},\n    \"last_error_present\": {s},\n    \"closed\": {s},\n    \"read_only\": {s},\n    \"has_header\": {s},\n    \"end_pos\": {d},\n    \"segment_entries\": {d},\n    \"segment_index\": {d}\n  }}\n}}\n", .{
                db_path,
                stats.memory.nodes.used,
                stats.memory.nodes.free,
                stats.memory.nodes.capacity,
                stats.memory.edges.used,
                stats.memory.edges.free,
                stats.memory.edges.capacity,
                stats.memory.embeddings.used,
                stats.memory.embeddings.free,
                stats.memory.embeddings.capacity,
                stats.wal.entries_written,
                stats.wal.entries_replayed,
                stats.wal.truncations,
                stats.wal.bytes_written,
                if (stats.wal_health.healthy) "true" else "false",
                stats.wal_health.io_error_count,
                if (stats.wal_health.last_error == null) "false" else "true",
                if (stats.wal_health.closed) "true" else "false",
                if (stats.wal_health.read_only) "true" else "false",
                if (stats.wal_health.has_header) "true" else "false",
                stats.wal_health.end_pos,
                stats.wal_health.segment_entries,
                stats.wal_health.segment_index,
            });
        } else {
            std.debug.print("NenDB status for '{s}':\n", .{db_path});
            std.debug.print("  Nodes: used={d} free={d} capacity={d}\n", .{ stats.memory.nodes.used, stats.memory.nodes.free, stats.memory.nodes.capacity });
            std.debug.print("  Edges: used={d} free={d} capacity={d}\n", .{ stats.memory.edges.used, stats.memory.edges.free, stats.memory.edges.capacity });
            std.debug.print("  Embeddings: used={d} free={d} capacity={d}\n", .{ stats.memory.embeddings.used, stats.memory.embeddings.free, stats.memory.embeddings.capacity });
            std.debug.print("  WAL: entries_written={d} entries_replayed={d} truncations={d} bytes_written={d}\n", .{ stats.wal.entries_written, stats.wal.entries_replayed, stats.wal.truncations, stats.wal.bytes_written });
            std.debug.print("  WAL Health: healthy={} io_errors={} closed={} read_only={} has_header={} end_pos={} seg_entries={} seg_index={}\n", .{
                stats.wal_health.healthy,
                stats.wal_health.io_error_count,
                stats.wal_health.closed,
                stats.wal_health.read_only,
                stats.wal_health.has_header,
                stats.wal_health.end_pos,
                stats.wal_health.segment_entries,
                stats.wal_health.segment_index,
            });
        }
        if (fail_on_unhealthy and !stats.wal_health.healthy) {
            std.debug.print("Unhealthy WAL detected. Exiting with failure.\n", .{});
            std.process.exit(1);
        }
        return;
    }

    if (std.mem.eql(u8, command, "init")) {
        // Initialize a database directory by creating/truncating the WAL file.
        try std.fs.cwd().makePath(db_path);
        var wal_path_buf: [256]u8 = undefined;
        const wal_path = try std.fmt.bufPrint(&wal_path_buf, "{s}/nendb.wal", .{db_path});
        const cwd = std.fs.cwd();
        var file = cwd.openFile(wal_path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => blk: {
                _ = try cwd.createFile(wal_path, .{});
                break :blk try cwd.openFile(wal_path, .{ .mode = .read_write });
            },
            else => return err,
        };
        defer file.close();
        try file.setEndPos(0);
        try file.sync();
        std.debug.print("Initialized NenDB at '{s}' (WAL created/truncated).\n", .{db_path});
        return;
    }

    if (std.mem.eql(u8, command, "snapshot")) {
        const GraphDB = @import("graphdb.zig").GraphDB;
        var db: GraphDB = undefined;
        try GraphDB.open_inplace(&db, db_path);
        defer db.deinit();
        try db.snapshot(db_path);
        std.debug.print("Snapshot written for '{s}'.\n", .{db_path});
        return;
    }

    if (std.mem.eql(u8, command, "restore")) {
        const GraphDB = @import("graphdb.zig").GraphDB;
        var db: GraphDB = undefined;
        try GraphDB.open_inplace(&db, db_path);
        defer db.deinit();
        try db.restore_from_snapshot(db_path);
        std.debug.print("Restore completed for '{s}'.\n", .{db_path});
        return;
    }

    if (std.mem.eql(u8, command, "check")) {
        var wal_path_buf: [256]u8 = undefined;
        const wal_path = try std.fmt.bufPrint(&wal_path_buf, "{s}/nendb.wal", .{db_path});
        var wal = try @import("wal.zig").Wal.open(wal_path);
        defer wal.close();
        const fix = true; // auto-fix
        const res = try wal.check(fix);
        std.debug.print("WAL check: ok={} entries={} truncated={} trunc_pos={}\n", .{ res.ok, res.entries, res.truncated, res.trunc_pos });
        return;
    }

    if (std.mem.eql(u8, command, "compact")) {
        const GraphDB = @import("graphdb.zig").GraphDB;
        var db: GraphDB = undefined;
        try GraphDB.open_inplace(&db, db_path);
        defer db.deinit();
        try db.snapshot(db_path);
        const removed = try db.wal.delete_segments();
        std.debug.print("Compaction done. Removed {d} WAL segments.\n", .{removed});
        return;
    }

    if (std.mem.eql(u8, command, "force-unlock")) {
        // Best-effort removal of a stale lock file. Do not use if another writer is running.
        var wal_path_buf: [256]u8 = undefined;
        const wal_path = try std.fmt.bufPrint(&wal_path_buf, "{s}/nendb.wal.lock", .{db_path});
        std.fs.cwd().deleteFile(wal_path) catch |e| switch (e) {
            error.FileNotFound => {
                std.debug.print("No lock file present at '{s}'.\n", .{wal_path});
                return;
            },
            else => return e,
        };
        std.debug.print("Removed stale lock file: {s}\n", .{wal_path});
        return;
    }

    // Command is 'up' (or default). Start DB at user-specified or default path
    if (std.mem.eql(u8, command, "up")) {
        const GraphDB = @import("graphdb.zig").GraphDB;
        var db: GraphDB = undefined;
        try GraphDB.open_inplace(&db, db_path);
        // Optional: override sync interval via env var
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "NENDB_SYNC_EVERY")) |val| {
            defer std.heap.page_allocator.free(val);
            const n = std.fmt.parseInt(u32, val, 10) catch 0;
            if (n > 0) db.wal.setSyncEvery(n);
        } else |_| {}
        if (std.process.getEnvVarOwned(std.heap.page_allocator, "NENDB_SEGMENT_SIZE")) |val2| {
            defer std.heap.page_allocator.free(val2);
            const n2 = std.fmt.parseInt(u64, val2, 10) catch 0;
            if (n2 > 0) db.wal.setSegmentSizeLimit(n2);
        } else |_| {}
        const pool = @import("memory/pool_v2.zig");
        const constants = @import("constants.zig");
        const node = pool.Node{
            .id = 42,
            .kind = 1,
            .reserved = [_]u8{0} ** 7,
            .props = [_]u8{0} ** constants.data.node_props_size,
        };
        try db.insert_node(node);
        std.debug.print("Inserted node with id 42.\n", .{});
        if (db.lookup_node(42)) |found| {
            std.debug.print("Lookup node 42: kind={} first_prop={}\n", .{ found.kind, found.props[0] });
        } else {
            std.debug.print("Lookup node 42 failed!\n", .{});
        }
        std.debug.print("NenDB started at '{s}'. Press Ctrl+C to exit.\n", .{db_path});

        // Graceful shutdown handling: wait for SIGINT/SIGTERM, then flush and snapshot
        // Portable signal handling: register handlers and idle until signal flips the flag
        var act = posix.Sigaction{
            .handler = .{ .handler = on_signal },
            .mask = posix.empty_sigset,
            .flags = 0,
        };
        posix.sigaction(posix.SIG.INT, &act, null);
        posix.sigaction(posix.SIG.TERM, &act, null);
        while (!shutdown_flag.load(.acquire)) {
            std.time.sleep(200 * std.time.ns_per_ms);
        }

        // On signal: flush WAL, take a snapshot, and exit
        std.debug.print("\nShutting down gracefully...\n", .{});
        db.wal.flush() catch |e| std.debug.print("WAL flush error: {}\n", .{e});
        db.snapshot(db_path) catch |e| std.debug.print("Snapshot error: {}\n", .{e});
        db.deinit();
        std.debug.print("Shutdown complete.\n", .{});
        return;
    }
}

fn run_demo(db: *nendb.NenDB, allocator: std.mem.Allocator) !void {
    std.debug.print("🔄 Running NenDB Demo...\n\n", .{});

    // Create some demo nodes
    var node_props_alice = [_]u8{0} ** 64;
    const alice_name = "Alice - AI Researcher";
    for (alice_name, 0..) |c, i| node_props_alice[i] = c;

    var node_props_bob = [_]u8{0} ** 64;
    const bob_name = "Bob - Graph Expert";
    for (bob_name, 0..) |c, i| node_props_bob[i] = c;

    var node_props_charlie = [_]u8{0} ** 64;
    const charlie_name = "Charlie - ML Engineer";
    for (charlie_name, 0..) |c, i| node_props_charlie[i] = c;

    const nodes = [_]nendb.NodeDef{
        .{ .id = "alice", .kind = 0, .props = node_props_alice },
        .{ .id = "bob", .kind = 0, .props = node_props_bob },
        .{ .id = "charlie", .kind = 0, .props = node_props_charlie },
    };

    std.debug.print("1️⃣ Batch inserting {d} nodes...\n", .{nodes.len});
    const node_batch = nendb.BatchNodeInsert{ .nodes = &nodes };
    const node_results = try db.batch_insert_nodes(node_batch);
    defer allocator.free(node_results);

    var successful_nodes: usize = 0;
    for (node_results) |result| {
        if (result != null) successful_nodes += 1;
    }
    std.debug.print("   ✅ Successfully inserted {d}/{d} nodes\n\n", .{ successful_nodes, nodes.len });

    // Create some demo edges
    const edges = [_]nendb.EdgeDef{
        .{ .from = "alice", .to = "bob", .label = 1, .props = [_]u8{0} ** 32 }, // collaborates_with
        .{ .from = "bob", .to = "charlie", .label = 1, .props = [_]u8{0} ** 32 }, // collaborates_with
        .{ .from = "alice", .to = "charlie", .label = 2, .props = [_]u8{0} ** 32 }, // mentors
    };

    std.debug.print("2️⃣ Batch inserting {d} edges...\n", .{edges.len});
    const edge_batch = nendb.BatchEdgeInsert{ .edges = &edges };
    const edge_results = try db.batch_insert_edges(edge_batch);
    defer allocator.free(edge_results);

    var successful_edges: usize = 0;
    for (edge_results) |result| {
        if (result != null) successful_edges += 1;
    }
    std.debug.print("   ✅ Successfully inserted {d}/{d} edges\n\n", .{ successful_edges, edges.len });

    // Demonstrate context assembly (AI-native feature)
    std.debug.print("3️⃣ Assembling context for Alice (AI-native feature)...\n", .{});
    var context_buf: [1024]u8 = undefined;
    const context_len = try db.assemble_context("alice", &context_buf);
    const context = context_buf[0..context_len];
    std.debug.print("   📝 Context: {s}\n", .{context});

    // Show final stats
    const final_stats = db.get_memory_stats();
    std.debug.print("4️⃣ Final Memory Stats:\n", .{});
    std.debug.print("   • Nodes used: {d}/{d}\n", .{ final_stats.nodes_used, final_stats.nodes_capacity });
    std.debug.print("   • Edges used: {d}/{d}\n", .{ final_stats.edges_used, final_stats.edges_capacity });
    std.debug.print("   • Memory usage: {d} bytes (still FIXED!)\n\n", .{final_stats.total_memory_bytes});
}
