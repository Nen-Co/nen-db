const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TigerBeetle-style NenDB CLI (Production Version)
    const exe = b.addExecutable(.{
        .name = "nendb-production",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // Short-name CLI for ease of use: `nen <command>`
    const nen_cli = b.addExecutable(.{
        .name = "nen",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(nen_cli);

    // Run command for the debug executable
    const run_cmd = b.addRunArtifact(nen_cli);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run NenDB Debug");
    run_step.dependOn(&run_cmd.step);

    // Removed test executables for missing files: minimal_test.zig, ultra_minimal_test.zig, no_wal_test.zig

    // Library module for use by other projects (TigerBeetle-style)
    const lib_mod = b.addModule("nendb", .{
        .root_source_file = .{ .cwd_relative = "src/lib_v2.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Tests for production version
    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/lib_v2.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Also run GraphDB tests
    const graphdb_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/graphdb.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_graphdb_tests = b.addRunArtifact(graphdb_tests);
    test_step.dependOn(&run_graphdb_tests.step);

    // Benchmarks (TigerBeetle-style)
    const bench_exe = b.addExecutable(.{
        .name = "nendb-bench",
        .root_source_file = .{ .cwd_relative = "tests/benchmark.zig" },
        .target = target,
        .optimize = optimize,
    });

    bench_exe.root_module.addImport("nendb", lib_mod);

    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Simple installers for the short-name CLI
    // User install: copies to $HOME/.local/bin (no sudo)
    const install_user_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        "mkdir -p \"$HOME/.local/bin\" && cp -f zig-out/bin/nen \"$HOME/.local/bin/nen\"",
    });
    install_user_cmd.step.dependOn(b.getInstallStep());
    const install_user_step = b.step("install-user", "Install 'nen' to $HOME/.local/bin");
    install_user_step.dependOn(&install_user_cmd.step);

    // System install: copies to /usr/local/bin (may require sudo)
    const install_system_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        "install -m 0755 zig-out/bin/nen /usr/local/bin/nen",
    });
    install_system_cmd.step.dependOn(b.getInstallStep());
    const install_system_step = b.step("install-system", "Install 'nen' to /usr/local/bin (may require sudo)");
    install_system_step.dependOn(&install_system_cmd.step);
}
