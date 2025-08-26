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
        return error.UnknownDbCommand;
    }
    return error.UnknownGroup;
}
