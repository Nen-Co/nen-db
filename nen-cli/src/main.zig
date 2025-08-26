const std = @import("std");
const commands = @import("commands/mod.zig");

pub fn main() !void {
    var it = std.process.args();
    _ = it.next();
    var list = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer list.deinit();
    while (it.next()) |a| try list.append(a);
    const slice = try list.toOwnedSlice();
    defer std.heap.page_allocator.free(slice);
    commands.dispatch(slice) catch |e| switch (e) {
        error.UnknownGroup => std.debug.print("Unknown group. Try 'nen help'.\n", .{}),
        error.UnknownDbCommand => std.debug.print("Unknown db command.\n", .{}),
        else => return e,
    };
}
