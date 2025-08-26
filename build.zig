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

    // Monitoring module
    const monitoring_mod = b.addModule("monitoring", .{
        .root_source_file = .{ .cwd_relative = "src/monitoring/resource_monitor.zig" },
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

    // Resource monitoring tests
    const monitoring_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "tests/test_resource_monitor.zig" },
        .target = target,
        .optimize = optimize,
    });
    monitoring_tests.root_module.addImport("monitoring", monitoring_mod);
    
    const run_monitoring_tests = b.addRunArtifact(monitoring_tests);
    test_step.dependOn(&run_monitoring_tests.step);

    // Optional benchmarks (gated by -Dbench)
    const bench_enabled = b.option(bool, "bench", "Enable building/running benchmark executables") orelse false;
    if (bench_enabled) {
        const bench_exe = b.addExecutable(.{
            .name = "nendb-bench",
            .root_source_file = .{ .cwd_relative = "tests/benchmark.zig" },
            .target = target,
            .optimize = optimize,
        });
        bench_exe.root_module.addImport("nendb", lib_mod);
        const run_bench = b.addRunArtifact(bench_exe);
        const bench_step = b.step("bench", "Run synthetic benchmarks");
        bench_step.dependOn(&run_bench.step);

        // Real performance benchmark (still synthetic placeholder)
        const real_bench_exe = b.addExecutable(.{
            .name = "nendb-real-bench",
            .root_source_file = .{ .cwd_relative = "tests/real_benchmark.zig" },
            .target = target,
            .optimize = optimize,
        });
        const run_real_bench = b.addRunArtifact(real_bench_exe);
        const real_bench_step = b.step("real-bench", "Run real performance benchmarks");
        real_bench_step.dependOn(&run_real_bench.step);
    }

    // Resource Monitor Demo
    const monitor_demo_exe = b.addExecutable(.{
        .name = "nendb-monitor-demo",
        .root_source_file = .{ .cwd_relative = "src/monitoring/demo.zig" },
        .target = target,
        .optimize = optimize,
    });
    monitor_demo_exe.root_module.addImport("monitoring", monitoring_mod);

    const run_monitor_demo = b.addRunArtifact(monitor_demo_exe);
    const monitor_demo_step = b.step("monitor-demo", "Run resource monitoring demo");
    monitor_demo_step.dependOn(&run_monitor_demo.step);

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
