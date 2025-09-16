// Pre-commit Hook
// Runs before every commit to catch errors early
// Install with: ln -s scripts/pre-commit-hook.zig .git/hooks/pre-commit

const std = @import("std");
const builtin = @import("builtin");

const CheckResult = struct {
    name: []const u8,
    success: bool,
    error_message: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🔍 Pre-commit Validation\n", .{});
    std.debug.print("=======================\n\n", .{});

    var total_checks: u32 = 0;
    var passed_checks: u32 = 0;
    var failed_checks: u32 = 0;

    // Check 1: Build validation
    std.debug.print("1. Build validation...\n", .{});
    const build_result = try checkBuild(allocator);
    total_checks += 1;
    if (build_result.success) {
        std.debug.print("   ✅ Build validation: PASSED\n", .{});
        passed_checks += 1;
    } else {
        std.debug.print("   ❌ Build validation: FAILED\n", .{});
        std.debug.print("   Error: {s}\n", .{build_result.error_message});
        failed_checks += 1;
    }

    // Check 2: Format validation
    std.debug.print("2. Format validation...\n", .{});
    const format_result = try checkFormat(allocator);
    total_checks += 1;
    if (format_result.success) {
        std.debug.print("   ✅ Format validation: PASSED\n", .{});
        passed_checks += 1;
    } else {
        std.debug.print("   ❌ Format validation: FAILED\n", .{});
        std.debug.print("   Error: {s}\n", .{format_result.error_message});
        failed_checks += 1;
    }

    // Check 3: Test validation
    std.debug.print("3. Test validation...\n", .{});
    const test_result = try checkTests(allocator);
    total_checks += 1;
    if (test_result.success) {
        std.debug.print("   ✅ Test validation: PASSED\n", .{});
        passed_checks += 1;
    } else {
        std.debug.print("   ❌ Test validation: FAILED\n", .{});
        std.debug.print("   Error: {s}\n", .{test_result.error_message});
        failed_checks += 1;
    }

    // Check 4: Dependency validation
    std.debug.print("4. Dependency validation...\n", .{});
    const dep_result = try checkDependencies(allocator);
    total_checks += 1;
    if (dep_result.success) {
        std.debug.print("   ✅ Dependency validation: PASSED\n", .{});
        passed_checks += 1;
    } else {
        std.debug.print("   ❌ Dependency validation: FAILED\n", .{});
        std.debug.print("   Error: {s}\n", .{dep_result.error_message});
        failed_checks += 1;
    }

    // Check 5: Lint validation
    std.debug.print("5. Lint validation...\n", .{});
    const lint_result = try checkLint(allocator);
    total_checks += 1;
    if (lint_result.success) {
        std.debug.print("   ✅ Lint validation: PASSED\n", .{});
        passed_checks += 1;
    } else {
        std.debug.print("   ❌ Lint validation: FAILED\n", .{});
        std.debug.print("   Error: {s}\n", .{lint_result.error_message});
        failed_checks += 1;
    }

    // Summary
    std.debug.print("\n📊 Pre-commit Summary\n", .{});
    std.debug.print("====================\n", .{});
    std.debug.print("Total checks: {}\n", .{total_checks});
    std.debug.print("Passed: {}\n", .{passed_checks});
    std.debug.print("Failed: {}\n", .{failed_checks});

    if (failed_checks == 0) {
        std.debug.print("\n🎉 All pre-commit checks passed! Ready to commit.\n", .{});
    } else {
        std.debug.print("\n❌ {} checks failed. Please fix before committing.\n", .{failed_checks});
        std.debug.print("\n💡 Quick fixes:\n", .{});
        std.debug.print("   - Run 'zig fmt' to fix formatting\n", .{});
        std.debug.print("   - Run 'zig build test' to fix tests\n", .{});
        std.debug.print("   - Run 'zig build' to fix build issues\n", .{});
        std.process.exit(1);
    }
}

fn checkBuild(allocator: std.mem.Allocator) !CheckResult {
    const args = [_][]const u8{ "zig", "build", "--release", "safe" };

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
        return CheckResult{ .name = "build", .success = true, .error_message = "" };
    } else {
        return CheckResult{ .name = "build", .success = false, .error_message = if (stderr.len > 0) stderr else stdout };
    }
}

fn checkFormat(allocator: std.mem.Allocator) !CheckResult {
    const args = [_][]const u8{ "zig", "fmt", "--check", "src/", "examples/", "tests/" };

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
        return CheckResult{ .name = "format", .success = true, .error_message = "" };
    } else {
        return CheckResult{ .name = "format", .success = false, .error_message = if (stderr.len > 0) stderr else stdout };
    }
}

fn checkTests(allocator: std.mem.Allocator) !CheckResult {
    const args = [_][]const u8{ "zig", "build", "test" };

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
        return CheckResult{ .name = "tests", .success = true, .error_message = "" };
    } else {
        return CheckResult{ .name = "tests", .success = false, .error_message = if (stderr.len > 0) stderr else stdout };
    }
}

fn checkDependencies(allocator: std.mem.Allocator) !CheckResult {
    // Check if nen-core exists and builds
    const nen_core_path = "../nen-core";
    var dir = std.fs.openDirAbsolute(nen_core_path, .{}) catch |err| {
        return CheckResult{ .name = "dependencies", .success = false, .error_message = "nen-core dependency not found" };
    };
    defer dir.close();

    // Try to build nen-core
    const args = [_][]const u8{ "zig", "build", "test" };

    var child = std.ChildProcess.init(&args, allocator);
    child.cwd = nen_core_path;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stdout);

    const stderr = try child.stderr.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(stderr);

    const term = try child.wait();

    if (term.Exited == 0) {
        return CheckResult{ .name = "dependencies", .success = true, .error_message = "" };
    } else {
        return CheckResult{ .name = "dependencies", .success = false, .error_message = if (stderr.len > 0) stderr else "nen-core build failed" };
    }
}

fn checkLint(allocator: std.mem.Allocator) !CheckResult {
    // Basic lint checks
    var issues = std.ArrayList([]const u8).init(allocator);
    defer issues.deinit();

    // Check for common issues
    const files_to_check = [_][]const u8{
        "src/",
        "examples/",
        "tests/",
    };

    for (files_to_check) |dir| {
        var walker = try std.fs.cwd().openIterableDir(dir, .{});
        defer walker.close();

        var iterator = walker.iterate();
        while (try iterator.next()) |entry| {
            if (std.mem.endsWith(u8, entry.name, ".zig")) {
                const file_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ dir, entry.name });
                defer allocator.free(file_path);

                const content = std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024) catch continue;
                defer allocator.free(content);

                // Check for TODO comments
                if (std.mem.indexOf(u8, content, "TODO") != null) {
                    try issues.append(try std.fmt.allocPrint(allocator, "TODO found in {s}", .{file_path}));
                }

                // Check for FIXME comments
                if (std.mem.indexOf(u8, content, "FIXME") != null) {
                    try issues.append(try std.fmt.allocPrint(allocator, "FIXME found in {s}", .{file_path}));
                }

                // Check for debug prints
                if (std.mem.indexOf(u8, content, "std.debug.print") != null) {
                    try issues.append(try std.fmt.allocPrint(allocator, "Debug print found in {s}", .{file_path}));
                }
            }
        }
    }

    if (issues.items.len == 0) {
        return CheckResult{ .name = "lint", .success = true, .error_message = "" };
    } else {
        var error_msg = std.ArrayList(u8).init(allocator);
        defer error_msg.deinit();

        try error_msg.appendSlice("Lint issues found:\n");
        for (issues.items) |issue| {
            try error_msg.appendSlice("  - ");
            try error_msg.appendSlice(issue);
            try error_msg.appendSlice("\n");
        }

        return CheckResult{ .name = "lint", .success = false, .error_message = error_msg.items };
    }
}
