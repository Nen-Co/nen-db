// CLI styling utilities (ANSI only if tty)
const std = @import("std");

pub const Style = struct {
    use_color: bool,

    pub fn detect() Style {
        const stdout = std.io.getStdOut();
        const is_tty = stdout.isTty();
        return Style{ .use_color = is_tty };
    }

    fn wrap(self: Style, code: []const u8, text: []const u8) []const u8 {
        return if (self.use_color) text else text; // placeholder no alloc
    }

    pub fn c(self: Style, code: []const u8, text: []const u8, writer: anytype) !void {
        if (self.use_color) try writer.print("\x1b[{s}m{s}\x1b[0m", .{ code, text }) else try writer.print("{s}", .{text});
    }

    pub fn heading(self: Style, text: []const u8, writer: anytype) !void {
        try self.c("1;38;5;81", text, writer);
    }
    pub fn accent(self: Style, text: []const u8, writer: anytype) !void {
        try self.c("38;5;209", text, writer);
    }
    pub fn ok(self: Style, text: []const u8, writer: anytype) !void {
        try self.c("38;5;82", text, writer);
    }
    pub fn warn(self: Style, text: []const u8, writer: anytype) !void {
        try self.c("38;5;214", text, writer);
    }
    pub fn err(self: Style, text: []const u8, writer: anytype) !void {
        try self.c("38;5;196", text, writer);
    }
};
