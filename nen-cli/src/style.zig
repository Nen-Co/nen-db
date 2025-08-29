const std = @import("std");
pub const Style = struct {
    use_color: bool,
    pub fn detect() Style {
        return .{ .use_color = std.io.getStdOut().isTty() };
    }
    fn out(self: Style, code: []const u8, text: []const u8, w: anytype) !void {
        if (self.use_color) try w.print("\x1b[{s}m{s}\x1b[0m", .{ code, text }) else try w.print("{s}", .{text});
    }
    pub fn banner(self: Style, w: anytype) !void {
        if (self.use_color) {
            try w.writeAll("\x1b[1;38;5;213m┌──────────────────────────────┐\n");
            try w.writeAll("│   nen • unified CLI toolkit  │\n");
            try w.writeAll("└──────────────────────────────┘\x1b[0m\n");
        } else try w.writeAll("nen (unified CLI)\n");
    }
    pub fn accent(self: Style, t: []const u8, w: anytype) !void {
        try self.out("38;5;81", t, w);
    }
    pub fn cmd(self: Style, t: []const u8, w: anytype) !void {
        try self.out("38;5;209", t, w);
    }
    pub fn dim(self: Style, t: []const u8, w: anytype) !void {
        try self.out("2", t, w);
    }
};
