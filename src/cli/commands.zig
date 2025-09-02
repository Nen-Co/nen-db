const std = @import("std");
const style_mod = @import("style.zig");

// We can't store generic anytype function pointers directly. For now define a concrete signature using std.Io.Writer for stdout.
pub const CommandFn = fn (writer: anytype, args: [][]const u8, sty: style_mod.Style) anyerror!void;

pub const Command = struct {
    name: []const u8,
    summary: []const u8,
    usage: []const u8,
    run: *const anyopaque, // store pointer to function; we'll cast when calling
};

pub fn print_table(commands: []const Command, sty: style_mod.Style, writer: anytype) !void {
    var max: usize = 0;
    for (commands) |c| {
        if (c.name.len > max) max = c.name.len;
    }
    for (commands) |c| {
        try sty.accent(c.name, writer);
        if (c.name.len < max) {
            var i: usize = 0;
            while (i < (max - c.name.len + 2)) : (i += 1) try writer.writeByte(' ');
        } else try writer.writeAll("  ");
        try writer.print("{s}\n", .{c.summary});
    }
}

pub fn find(commands: []const Command, name: []const u8) ?Command {
    for (commands) |c| {
        if (std.mem.eql(u8, c.name, name)) return c;
    }
    return null;
}
