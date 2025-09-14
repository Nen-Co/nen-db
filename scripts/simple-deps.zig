// Simple Dependency Check
// Quick check for required dependencies

const std = @import("std");

const DEPENDENCIES = [_][]const u8{
    "../nen-core",
    "../nen-io",
    "../nen-json",
    "../nen-net",
};

pub fn main() !void {
    std.debug.print("🔗 Quick Dependency Check\n", .{});
    std.debug.print("=========================\n\n", .{});

    var all_found = true;

    for (DEPENDENCIES) |dep_path| {
        std.debug.print("Checking {s}... ", .{dep_path});

        var dir = std.fs.cwd().openDir(dep_path, .{}) catch {
            std.debug.print("❌ NOT FOUND\n", .{});
            all_found = false;
            continue;
        };
        defer dir.close();

        std.debug.print("✅ FOUND\n", .{});
    }

    if (all_found) {
        std.debug.print("\n🎉 All dependencies found!\n", .{});
    } else {
        std.debug.print("\n❌ Some dependencies missing!\n", .{});
        std.process.exit(1);
    }
}
