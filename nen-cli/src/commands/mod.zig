const std = @import("std");
const style = @import("../style.zig");

fn cmd_help(sty: style.Style) !void {
    const w = std.io.getStdOut().writer();
    try sty.banner(w);
    try w.writeAll("Usage: nen <group> <command> [args]\n\nGroups:\n  db      Graph database ops (status)\n  cache   (coming)\n  flow    (coming)\n\nExamples:\n  nen db status ./data\n\n");
}

fn db_status(sty: style.Style, args: [][]const u8) !void {
    const path = if (args.len > 0) args[0] else ".";
    const GraphDB = @import("nendb_graph").GraphDB;
    var db: GraphDB = undefined;
    try GraphDB.open_read_only(&db, path);
    defer db.deinit();
    const s = db.get_stats();
    const w = std.io.getStdOut().writer();
    try sty.accent("NenDB Status\n", w);
    try w.print("Path: {s}\nNodes {d}/{d}/{d}\nEdges {d}/{d}/{d}\nEmbeddings {d}/{d}/{d}\nHealthy {} Entries {} Bytes {}\n", .{ path, s.memory.nodes.used, s.memory.nodes.free, s.memory.nodes.capacity, s.memory.edges.used, s.memory.edges.free, s.memory.edges.capacity, s.memory.embeddings.used, s.memory.embeddings.free, s.memory.embeddings.capacity, s.wal_health.healthy, s.wal.entries_written, s.wal.bytes_written });
}

fn db_init(sty: style.Style, args: [][]const u8) !void {
    const path = if (args.len > 0) args[0] else "./data";
    try std.fs.cwd().makePath(path);
    var buf: [256]u8 = undefined;
    const wal_path = try std.fmt.bufPrint(&buf, "{s}/nendb.wal", .{path});
    const cwd = std.fs.cwd();
    var file = cwd.createFile(wal_path, .{}) catch |e| switch (e) {
        error.PathAlreadyExists => try cwd.openFile(wal_path, .{ .mode = .read_write }),
        else => return e,
    };
    defer file.close();
    try file.setEndPos(0);
    try file.sync();
    const w = std.io.getStdOut().writer();
    try sty.accent("Initialized NenDB at ", w);
    try w.print("{s}\n", .{path});
}

fn db_up(sty: style.Style, args: [][]const u8) !void {
    _ = sty;
    const path = if (args.len > 0) args[0] else ".";
    const GraphDB = @import("nendb_graph").GraphDB;
    var db: GraphDB = undefined;
    try GraphDB.open_inplace(&db, path);
    defer db.deinit();
    const w = std.io.getStdOut().writer();
    try w.print("NenDB up at {s}. (Ctrl+C to exit not implemented in umbrella yet)\n", .{path});
    // For now just show status and exit.
    const s = db.get_stats();
    try w.print("Nodes used={d} free={d}\n", .{ s.memory.nodes.used, s.memory.nodes.free });
}

fn db_snapshot(sty: style.Style, args: [][]const u8) !void {
    _ = sty;
    const path = if (args.len > 0) args[0] else ".";
    const GraphDB = @import("nendb_graph").GraphDB;
    var db: GraphDB = undefined;
    try GraphDB.open_inplace(&db, path);
    defer db.deinit();
    try db.snapshot(path);
    std.debug.print("Snapshot written for '{s}'\n", .{path});
}

fn db_restore(sty: style.Style, args: [][]const u8) !void {
    _ = sty;
    const path = if (args.len > 0) args[0] else ".";
    const GraphDB = @import("nendb_graph").GraphDB;
    var db: GraphDB = undefined;
    try GraphDB.open_inplace(&db, path);
    defer db.deinit();
    try db.restore_from_snapshot(path);
    std.debug.print("Restore completed for '{s}'\n", .{path});
}

pub fn dispatch(args: [][]const u8) !void {
    const sty = style.Style.detect();
    if (args.len == 0) return cmd_help(sty);
    const group = args[0];
    const rest = args[1..];
    if (std.mem.eql(u8, group, "help")) return cmd_help(sty);
    if (std.mem.eql(u8, group, "db")) {
        if (rest.len == 0 or std.mem.eql(u8, rest[0], "help")) return db_status(sty, &.{});
        const sub = rest[0];
        const sub_args = rest[1..];
        if (std.mem.eql(u8, sub, "status")) return db_status(sty, sub_args);
        if (std.mem.eql(u8, sub, "init")) return db_init(sty, sub_args);
        if (std.mem.eql(u8, sub, "up")) return db_up(sty, sub_args);
        if (std.mem.eql(u8, sub, "snapshot")) return db_snapshot(sty, sub_args);
        if (std.mem.eql(u8, sub, "restore")) return db_restore(sty, sub_args);
        return error.UnknownDbCommand;
    }
    return error.UnknownGroup;
}
