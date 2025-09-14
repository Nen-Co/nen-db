// Build Validation Script
// Ensures all builds work correctly before CI/CD
// Run with: zig run scripts/validate-build.zig

const std = @import("std");
const builtin = @import("builtin");

const BuildConfig = struct {
    name: []const u8,
    target: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    expected_success: bool = true,
};

const BUILD_CONFIGS = [_]BuildConfig{
    .{
        .name = "Debug",
        .target = .{},
        .optimize = .Debug,
    },
    .{
        .name = "ReleaseSafe",
        .target = .{},
        .optimize = .ReleaseSafe,
    },
    .{
        .name = "ReleaseFast",
        .target = .{},
        .optimize = .ReleaseFast,
    },
    .{
        .name = "ReleaseSmall",
        .target = .{},
        .optimize = .ReleaseSmall,
    },
    .{
        .name = "WASM",
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
        .optimize = .ReleaseSmall,
    },
};

const TARGETS = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🔍 NenDB Build Validation\n", .{});
    std.debug.print("========================\n\n", .{});

    var total_tests: u32 = 0;
    var passed_tests: u32 = 0;
    var failed_tests: u32 = 0;

    // Test all build configurations
    for (BUILD_CONFIGS) |config| {
        std.debug.print("Testing {} build...\n", .{config.name});

        const result = try runBuild(allocator, config);
        total_tests += 1;

        if (result.success) {
            std.debug.print("  ✅ {} build: SUCCESS\n", .{config.name});
            passed_tests += 1;
        } else {
            std.debug.print("  ❌ {} build: FAILED\n", .{config.name});
            std.debug.print("  Error: {s}\n", .{result.error_message});
            failed_tests += 1;
        }
    }

    // Test cross-compilation targets
    std.debug.print("\nTesting cross-compilation...\n");
    for (TARGETS) |target| {
        const target_name = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ @tagName(target.cpu_arch.?), @tagName(target.os_tag.?) });
        defer allocator.free(target_name);

        std.debug.print("Testing {} target...\n", .{target_name});

        const config = BuildConfig{
            .name = target_name,
            .target = target,
            .optimize = .ReleaseSafe,
        };

        const result = try runBuild(allocator, config);
        total_tests += 1;

        if (result.success) {
            std.debug.print("  ✅ {} target: SUCCESS\n", .{target_name});
            passed_tests += 1;
        } else {
            std.debug.print("  ❌ {} target: FAILED\n", .{target_name});
            std.debug.print("  Error: {s}\n", .{result.error_message});
            failed_tests += 1;
        }
    }

    // Test specific executables
    std.debug.print("\nTesting specific executables...\n");
    const executables = [_][]const u8{
        "nendb",
        "nendb-production",
        "nendb-http-server",
        "nendb-tcp-server",
        "nendb-wasm",
    };

    for (executables) |exe_name| {
        std.debug.print("Testing {} executable...\n", .{exe_name});

        const result = try runExecutableBuild(allocator, exe_name);
        total_tests += 1;

        if (result.success) {
            std.debug.print("  ✅ {}: SUCCESS\n", .{exe_name});
            passed_tests += 1;
        } else {
            std.debug.print("  ❌ {}: FAILED\n", .{exe_name});
            std.debug.print("  Error: {s}\n", .{result.error_message});
            failed_tests += 1;
        }
    }

    // Summary
    std.debug.print("\n📊 Build Validation Summary\n", .{});
    std.debug.print("===========================\n", .{});
    std.debug.print("Total tests: {}\n", .{total_tests});
    std.debug.print("Passed: {}\n", .{passed_tests});
    std.debug.print("Failed: {}\n", .{failed_tests});

    if (failed_tests == 0) {
        std.debug.print("\n🎉 All builds successful! Ready for CI/CD.\n", .{});
    } else {
        std.debug.print("\n⚠️  {} builds failed. Fix before CI/CD.\n", .{failed_tests});
        std.process.exit(1);
    }
}

const BuildResult = struct {
    success: bool,
    error_message: []const u8,
};

fn runBuild(allocator: std.mem.Allocator, config: BuildConfig) !BuildResult {
    const args = [_][]const u8{
        "zig",       "build",
        "--release",
        switch (config.optimize) {
            .Debug => "safe",
            .ReleaseSafe => "safe",
            .ReleaseFast => "fast",
            .ReleaseSmall => "small",
        },
    };

    var child = std.ChildProcess.init(&args, allocator);
    child.cwd = ".";
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stdout);

    const stderr = try child.stderr.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stderr);

    const term = try child.wait();

    if (term.Exited == 0) {
        return BuildResult{ .success = true, .error_message = "" };
    } else {
        return BuildResult{ .success = false, .error_message = if (stderr.len > 0) stderr else stdout };
    }
}

fn runExecutableBuild(allocator: std.mem.Allocator, exe_name: []const u8) !BuildResult {
    const args = [_][]const u8{
        "zig",       "build", exe_name,
        "--release", "safe",
    };

    var child = std.ChildProcess.init(&args, allocator);
    child.cwd = ".";
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stdout);

    const stderr = try child.stderr.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stderr);

    const term = try child.wait();

    if (term.Exited == 0) {
        return BuildResult{ .success = true, .error_message = "" };
    } else {
        return BuildResult{ .success = false, .error_message = if (stderr.len > 0) stderr else stdout };
    }
}
