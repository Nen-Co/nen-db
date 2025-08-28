const std = @import("std");

// Minimal placeholder for super_io functionality actually used by Nen.
// Extend as needed with real implementations instead of pulling full upstream.
pub const ascii = struct {
    pub inline fn isAlpha(c: u8) bool { return (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z'); }
    pub inline fn isDigit(c: u8) bool { return c >= '0' and c <= '9'; }
};

pub fn fastTrimLeft(s: []const u8) []const u8 {
    var i: usize = 0;
    while (i < s.len and (s[i] == ' ' or s[i] == '\t' or s[i] == '\n' or s[i] == '\r')) : (i += 1) {}
    return s[i..];
}

pub fn fastTrimRight(s: []const u8) []const u8 {
    if (s.len == 0) return s;
    var end: usize = s.len;
    while (end > 0) : (end -= 1) {
        const c = s[end - 1];
        if (c != ' ' and c != '\t' and c != '\n' and c != '\r') break;
    }
    return s[0..end];
}

pub fn fastTrim(s: []const u8) []const u8 {
    return fastTrimRight(fastTrimLeft(s));
}

pub fn writeAll(writer: anytype, data: []const u8) !void {
    try writer.writeAll(data);
}

pub fn println(writer: anytype, data: []const u8) !void {
    try writer.writeAll(data);
    try writer.writeByte('\n');
}

pub fn demo() void {
    const stdout = std.io.getStdOut().writer();
    _ = stdout; // placeholder usage
}
