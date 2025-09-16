// Comprehensive Build Script
// Runs all builds and validations to ensure zero errors
// Run with: zig run scripts/build-all.zig

const std = @import("std");
const builtin = @import("builtin");

const BuildStep = struct {
    name: []const u8,
    command: []const []const u8,
    required: bool = true,
    timeout_seconds: u32 = 300,
};

const BUILD_STEPS = [_]BuildStep{
    .{
        .name = "Dependency Check",
        .command = &[_][]const u8{ "zig", "run", "scripts/check-dependencies.zig" },
    },
    .{
        .name = "Format Check",
        .command = &[_][]const u8{ "zig", "fmt", "--check", "src/", "examples/", "tests/" },
    },
    .{
        .name = "Debug Build",
        .command = &[_][]const u8{ "zig", "build" },
    },
    .{
        .name = "ReleaseSafe Build",
        .command = &[_][]const u8{ "zig", "build", "--release", "safe" },
    },
    .{
        .name = "ReleaseFast Build",
        .command = &[_][]const u8{ "zig", "build", "--release", "fast" },
    },
    .{
        .name = "ReleaseSmall Build",
        .command = &[_][]const u8{ "zig", "build", "--release", "small" },
    },
    .{
        .name = "WASM Build",
        .command = &[_][]const u8{ "zig", "build", "wasm" },
    },
    .{
        .name = "Unit Tests",
        .command = &[_][]const u8{ "zig", "build", "test-unit" },
    },
    .{
        .name = "Integration Tests",
        .command = &[_][]const u8{ "zig", "build", "test-integration" },
    },
    .{
        .name = "Performance Tests",
        .command = &[_][]const u8{ "zig", "build", "test-performance" },
    },
    .{
        .name = "Algorithm Tests",
        .command = &[_][]const u8{ "zig", "build", "test-algorithms" },
    },
    .{
        .name = "nen-core Integration Demo",
        .command = &[_][]const u8{ "zig", "build", "demo-nen-core" },
    },
    .{
        .name = "Cross-compilation (Linux)",
        .command = &[_][]const u8{ "zig", "build", "--release", "fast", "-Dtarget=x86_64-linux-gnu" },
    },
    .{
        .name = "Cross-compilation (macOS)",
        .command = &[_][]const u8{ "zig", "build", "--release", "fast", "-Dtarget=x86_64-macos" },
    },
    .{
        .name = "Cross-compilation (Windows)",
        .command = &[_][]const u8{ "zig", "build", "--release", "fast", "-Dtarget=x86_64-windows-gnu" },
    },
};

const StepResult = struct {
    name: []const u8,
    success: bool,
    duration_ms: u64,
    error_message: ?[]const u8 = null,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 Comprehensive Build Validation\n", .{});
    std.debug.print("==================================\n\n", .{});

    var results = std.ArrayList(StepResult).init(allocator);
    defer results.deinit();

    var total_steps: u32 = 0;
    var passed_steps: u32 = 0;
    var failed_steps: u32 = 0;
    var total_duration_ms: u64 = 0;

    // Run all build steps
    for (BUILD_STEPS) |step| {
        std.debug.print("🔨 {s}...\n", .{step.name});
        total_steps += 1;

        const start_time = std.time.nanoTimestamp();
        const result = try runBuildStep(allocator, step);
        const end_time = std.time.nanoTimestamp();
        const duration_ms = @as(u64, @intCast((end_time - start_time) / 1_000_000));
        total_duration_ms += duration_ms;

        const step_result = StepResult{
            .name = step.name,
            .success = result.success,
            .duration_ms = duration_ms,
            .error_message = result.error_message,
        };
        try results.append(step_result);

        if (result.success) {
            passed_steps += 1;
            std.debug.print("   ✅ {s}: SUCCESS ({d}ms)\n", .{ step.name, duration_ms });
        } else {
            failed_steps += 1;
            std.debug.print("   ❌ {s}: FAILED ({d}ms)\n", .{ step.name, duration_ms });
            if (result.error_message) |err_msg| {
                std.debug.print("   Error: {s}\n", .{err_msg});
            }

            if (step.required) {
                std.debug.print("   ⚠️  This is a required step - stopping build\n", .{});
                break;
            } else {
                std.debug.print("   ⚠️  This is an optional step - continuing\n", .{});
            }
        }
        std.debug.print("\n", .{});
    }

    // Summary
    std.debug.print("📊 Build Summary\n", .{});
    std.debug.print("================\n", .{});
    std.debug.print("Total steps: {}\n", .{total_steps});
    std.debug.print("Passed: {}\n", .{passed_steps});
    std.debug.print("Failed: {}\n", .{failed_steps});
    std.debug.print("Total duration: {d}ms ({d:.1}s)\n", .{ total_duration_ms, @as(f64, @floatFromInt(total_duration_ms)) / 1000.0 });

    // Detailed results
    std.debug.print("\n📋 Detailed Results\n", .{});
    std.debug.print("===================\n", .{});
    for (results.items) |result| {
        const status = if (result.success) "✅" else "❌";
        std.debug.print("{s} {s}: {d}ms\n", .{ status, result.name, result.duration_ms });
    }

    if (failed_steps == 0) {
        std.debug.print("\n🎉 All builds successful! Ready for CI/CD.\n", .{});
        std.debug.print("🚀 You can now safely push to the repository.\n", .{});
    } else {
        std.debug.print("\n❌ {} builds failed. Please fix before proceeding.\n", .{failed_steps});
        std.debug.print("\n💡 Quick fixes:\n", .{});
        std.debug.print("   - Run 'zig fmt' to fix formatting\n", .{});
        std.debug.print("   - Run 'zig build test' to fix tests\n", .{});
        std.debug.print("   - Run 'zig build' to fix build issues\n", .{});
        std.debug.print("   - Check dependencies with 'zig run scripts/check-dependencies.zig'\n", .{});
        std.process.exit(1);
    }
}

const BuildStepResult = struct {
    success: bool,
    error_message: ?[]const u8 = null,
};

fn runBuildStep(allocator: std.mem.Allocator, step: BuildStep) !BuildStepResult {
    var child = std.ChildProcess.init(step.command, allocator);
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
        return BuildStepResult{ .success = true };
    } else {
        return BuildStepResult{ .success = false, .error_message = if (stderr.len > 0) stderr else stdout };
    }
}
