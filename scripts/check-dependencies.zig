// Dependency Management Script
// Ensures all dependencies are available and compatible
// Run with: zig run scripts/check-dependencies.zig

const std = @import("std");
const builtin = @import("builtin");

const Dependency = struct {
    name: []const u8,
    path: []const u8,
    required: bool,
    min_version: ?[]const u8 = null,
};

const DEPENDENCIES = [_]Dependency{
    .{
        .name = "nen-core",
        .path = "../nen-core",
        .required = true,
        .min_version = "0.1.0",
    },
    .{
        .name = "nen-io",
        .path = "../nen-io",
        .required = true,
        .min_version = "0.1.0",
    },
    .{
        .name = "nen-json",
        .path = "../nen-json",
        .required = true,
        .min_version = "0.1.0",
    },
    .{
        .name = "nen-net",
        .path = "../nen-net",
        .required = true,
        .min_version = "0.1.0",
    },
};

const DependencyStatus = struct {
    name: []const u8,
    found: bool,
    buildable: bool,
    version: ?[]const u8 = null,
    error_message: ?[]const u8 = null,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🔗 Dependency Check\n", .{});
    std.debug.print("==================\n\n", .{});

    var total_deps: u32 = 0;
    var found_deps: u32 = 0;
    var buildable_deps: u32 = 0;
    var failed_deps: u32 = 0;

    for (DEPENDENCIES) |dep| {
        std.debug.print("Checking {}...\n", .{dep.name});
        total_deps += 1;

        const status = try checkDependency(allocator, dep);

        if (status.found) {
            found_deps += 1;
            std.debug.print("  ✅ Found: {s}\n", .{dep.path});

            if (status.version) |version| {
                std.debug.print("  📋 Version: {s}\n", .{version});
            }

            if (status.buildable) {
                buildable_deps += 1;
                std.debug.print("  ✅ Buildable: YES\n", .{});
            } else {
                failed_deps += 1;
                std.debug.print("  ❌ Buildable: NO\n", .{});
                if (status.error_message) |err_msg| {
                    std.debug.print("  Error: {s}\n", .{err_msg});
                }
            }
        } else {
            if (dep.required) {
                failed_deps += 1;
                std.debug.print("  ❌ Required dependency missing: {s}\n", .{dep.path});
            } else {
                std.debug.print("  ⚠️  Optional dependency missing: {s}\n", .{dep.path});
            }
        }
        std.debug.print("\n", .{});
    }

    // Summary
    std.debug.print("📊 Dependency Summary\n", .{});
    std.debug.print("====================\n", .{});
    std.debug.print("Total dependencies: {}\n", .{total_deps});
    std.debug.print("Found: {}\n", .{found_deps});
    std.debug.print("Buildable: {}\n", .{buildable_deps});
    std.debug.print("Failed: {}\n", .{failed_deps});

    if (failed_deps == 0) {
        std.debug.print("\n🎉 All dependencies are available and buildable!\n", .{});
    } else {
        std.debug.print("\n❌ {} dependencies failed. Please fix before proceeding.\n", .{failed_deps});
        std.debug.print("\n💡 Quick fixes:\n", .{});
        std.debug.print("   - Clone missing dependencies: git clone <repo-url>\n", .{});
        std.debug.print("   - Update dependencies: git pull\n", .{});
        std.debug.print("   - Fix build issues in dependencies\n", .{});
        std.process.exit(1);
    }
}

fn checkDependency(allocator: std.mem.Allocator, dep: Dependency) !DependencyStatus {
    // Check if directory exists
    var dir = std.fs.openDirAbsolute(dep.path, .{}) catch {
        return DependencyStatus{
            .name = dep.name,
            .found = false,
            .buildable = false,
            .error_message = "Directory not found",
        };
    };
    defer dir.close();

    // Check if build.zig exists
    const build_file = try std.fmt.allocPrint(allocator, "{s}/build.zig", .{dep.path});
    defer allocator.free(build_file);

    std.fs.cwd().access(build_file, .{}) catch {
        return DependencyStatus{
            .name = dep.name,
            .found = true,
            .buildable = false,
            .error_message = "build.zig not found",
        };
    };

    // Try to get version from build.zig
    const version = try getVersionFromBuildFile(allocator, build_file);

    // Try to build the dependency
    const build_result = try tryBuildDependency(allocator, dep.path);

    return DependencyStatus{
        .name = dep.name,
        .found = true,
        .buildable = build_result.success,
        .version = version,
        .error_message = if (build_result.success) null else build_result.error_message,
    };
}

fn getVersionFromBuildFile(allocator: std.mem.Allocator, build_file: []const u8) !?[]const u8 {
    const content = std.fs.cwd().readFileAlloc(allocator, build_file, 1024 * 1024) catch return null;
    defer allocator.free(content);

    // Look for version pattern
    const version_pattern = "version = std.SemanticVersion{";
    if (std.mem.indexOf(u8, content, version_pattern)) |pos| {
        const start = pos + version_pattern.len;
        const end = std.mem.indexOf(u8, content[start..], "}") orelse return null;
        return content[start .. start + end];
    }

    return null;
}

const BuildResult = struct {
    success: bool,
    error_message: ?[]const u8 = null,
};

fn tryBuildDependency(allocator: std.mem.Allocator, dep_path: []const u8) !BuildResult {
    const args = [_][]const u8{ "zig", "build", "test" };

    var child = std.process.Child.init(&args, allocator);
    child.cwd = dep_path;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stdout);

    const stderr = try child.stderr.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stderr);

    const term = try child.wait();

    if (term.Exited == 0) {
        return BuildResult{ .success = true };
    } else {
        const error_msg = if (stderr.len > 0) stderr else stdout;
        return BuildResult{ .success = false, .error_message = error_msg };
    }
}
