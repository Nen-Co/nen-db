const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = .ReleaseSafe; // Always build in safe mode for production reliability

    //NenDB CLI (Production Version)
    const exe = b.addExecutable(.{
        .name = "nendb-production",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    // Dedicated NenDB CLI binary (renamed from generic 'nen' to avoid collision with unified multi-product CLI)
    const nen_cli = b.addExecutable(.{
        .name = "nendb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
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
    // Primary library module now references legacy consolidated lib.zig after cleanup
    const lib_mod = b.addModule("nendb", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Algorithms demo executable
    const algorithms_demo = b.addExecutable(.{
        .name = "algorithms-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/algorithms_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const algorithms_mod = b.addModule("algorithms", .{
        .root_source_file = b.path("src/algorithms/algorithms.zig"),
        .target = target,
        .optimize = optimize,
    });
    algorithms_mod.addImport("nendb", lib_mod);

    algorithms_demo.root_module.addImport("nendb", lib_mod);
    algorithms_demo.root_module.addImport("algorithms", algorithms_mod);

    const run_algorithms_demo = b.addRunArtifact(algorithms_demo);
    const algorithms_demo_step = b.step("demo", "Run algorithms demo");
    algorithms_demo_step.dependOn(&run_algorithms_demo.step);

    // Compiled Cypher + Vector demo executable
    const compiled_cypher_demo = b.addExecutable(.{
        .name = "compiled-cypher-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/compiled_cypher_vector_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    compiled_cypher_demo.root_module.addImport("nendb", lib_mod);

    const run_compiled_cypher_demo = b.addRunArtifact(compiled_cypher_demo);
    const compiled_cypher_demo_step = b.step("demo-compiled-cypher", "Run compiled Cypher + vector demo");
    compiled_cypher_demo_step.dependOn(&run_compiled_cypher_demo.step);

    // Batch processing demo (TigerBeetle-style)
    const batch_processing_demo = b.addExecutable(.{
        .name = "nendb-batch-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/batch_processing_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    batch_processing_demo.root_module.addImport("nendb", lib_mod);

    const run_batch_processing_demo = b.addRunArtifact(batch_processing_demo);
    const batch_processing_demo_step = b.step("demo-batch-processing", "Run TigerBeetle-style batch processing demo");
    batch_processing_demo_step.dependOn(&run_batch_processing_demo.step);

    // Complete TigerBeetle-style batch processing demo
    const tigerbeetle_batch_demo = b.addExecutable(.{
        .name = "nendb-tigerbeetle-batch-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/tigerbeetle_style_batch_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tigerbeetle_batch_demo.root_module.addImport("nendb", lib_mod);

    const run_tigerbeetle_batch_demo = b.addRunArtifact(tigerbeetle_batch_demo);
    const tigerbeetle_batch_demo_step = b.step("demo-tigerbeetle-batch", "Run complete TigerBeetle-style batch processing demo");
    tigerbeetle_batch_demo_step.dependOn(&run_tigerbeetle_batch_demo.step);

    // Monitoring module
    const monitoring_mod = b.addModule("monitoring", .{
        .root_source_file = b.path("src/monitoring/resource_monitor.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ===== NEW TDD WORKFLOW: CATEGORIZED TEST SUITES =====

    // 1. UNIT TESTS (Fast, isolated, no external dependencies)
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/unit/unit_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    unit_tests.root_module.addImport("nendb", lib_mod);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const unit_test_step = b.step("test-unit", "Run unit tests (fast, isolated)");
    unit_test_step.dependOn(&run_unit_tests.step);

    // 2. INTEGRATION TESTS (Slower, real data, external dependencies)
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration/integration_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    integration_tests.root_module.addImport("nendb", lib_mod);
    integration_tests.root_module.addImport("monitoring", monitoring_mod);

    const run_integration_tests = b.addRunArtifact(integration_tests);
    const integration_test_step = b.step("test-integration", "Run integration tests (real data)");
    integration_test_step.dependOn(&run_integration_tests.step);

    // 3. PERFORMANCE TESTS (Benchmarking, performance assertions)
    const performance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/performance/performance_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    performance_tests.root_module.addImport("nendb", lib_mod);

    const run_performance_tests = b.addRunArtifact(performance_tests);
    const performance_test_step = b.step("test-performance", "Run performance tests (benchmarking)");
    performance_test_step.dependOn(&run_performance_tests.step);

    // 4. STRESS TESTS (Long running, edge cases, memory pressure)
    const stress_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/stress/stress_tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    stress_tests.root_module.addImport("nendb", lib_mod);

    const run_stress_tests = b.addRunArtifact(stress_tests);
    const stress_test_step = b.step("test-stress", "Run stress tests (long running)");
    stress_test_step.dependOn(&run_stress_tests.step);

    // ===== LEGACY TEST SUPPORT (Maintained for compatibility) =====

    // Tests for production version
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run all tests (legacy compatibility)");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Also run GraphDB tests
    const graphdb_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/graphdb.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_graphdb_tests = b.addRunArtifact(graphdb_tests);
    test_step.dependOn(&run_graphdb_tests.step);

    // Resource monitoring tests (legacy - moved to tests/legacy/)
    const monitoring_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/legacy/test_resource_monitor.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    monitoring_tests.root_module.addImport("monitoring", monitoring_mod);

    const run_monitoring_tests = b.addRunArtifact(monitoring_tests);
    test_step.dependOn(&run_monitoring_tests.step);

    // Cypher parser tests (query language subset)
    const query_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/legacy/test_cypher_parser.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    query_tests.root_module.addAnonymousImport("query", .{ .root_source_file = b.path("src/query/query.zig") });
    const run_query_tests = b.addRunArtifact(query_tests);
    test_step.dependOn(&run_query_tests.step);

    // New Cypher parser tests
    const query_tests_new = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/legacy/test_cypher_parser_new.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    query_tests_new.root_module.addAnonymousImport("query", .{ .root_source_file = b.path("src/query/query.zig") });
    const run_query_tests_new = b.addRunArtifact(query_tests_new);
    test_step.dependOn(&run_query_tests_new.step);

    // Advanced Cypher features tests
    const query_tests_advanced = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/legacy/test_cypher_advanced.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    query_tests_advanced.root_module.addAnonymousImport("query", .{ .root_source_file = b.path("src/query/query.zig") });
    const run_query_tests_advanced = b.addRunArtifact(query_tests_advanced);
    test_step.dependOn(&run_query_tests_advanced.step);

    // Cypher integration tests
    const query_tests_integration = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/legacy/test_cypher_integration.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    query_tests_integration.root_module.addAnonymousImport("query", .{ .root_source_file = b.path("src/query/query.zig") });
    query_tests_integration.root_module.addImport("nendb", lib_mod);
    const run_query_tests_integration = b.addRunArtifact(query_tests_integration);
    test_step.dependOn(&run_query_tests_integration.step);

    // ===== ENHANCED BENCHMARKING SUPPORT =====

    // Optional benchmarks (gated by -Dbench)
    const bench_enabled = b.option(bool, "bench", "Enable building/running benchmark executables") orelse false;
    if (bench_enabled) {
        const bench_exe = b.addExecutable(.{
            .name = "nendb-bench",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/benchmark.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        bench_exe.root_module.addImport("nendb", lib_mod);
        const run_bench = b.addRunArtifact(bench_exe);
        const bench_step = b.step("bench", "Run synthetic benchmarks");
        bench_step.dependOn(&run_bench.step);

        // Real performance benchmark (still synthetic placeholder)
        const real_bench_exe = b.addExecutable(.{
            .name = "nendb-real-bench",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/real_benchmark.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_real_bench = b.addRunArtifact(real_bench_exe);
        const real_bench_step = b.step("real-bench", "Run real performance benchmarks");
        real_bench_step.dependOn(&run_real_bench.step);
    }

    // ===== PERFORMANCE PROFILING SUPPORT =====

    // Performance profiling executable
    const profile_exe = b.addExecutable(.{
        .name = "nendb-profile",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/profile/performance_profile.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    profile_exe.root_module.addImport("nendb", lib_mod);

    const run_profile = b.addRunArtifact(profile_exe);
    const profile_step = b.step("profile", "Run performance profiling");
    profile_step.dependOn(&run_profile.step);

    // ===== MEMORY ANALYSIS SUPPORT =====

    // Memory usage analysis
    const memory_analysis_exe = b.addExecutable(.{
        .name = "nendb-memory",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/memory/memory_analysis.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    memory_analysis_exe.root_module.addImport("nendb", lib_mod);

    const run_memory_analysis = b.addRunArtifact(memory_analysis_exe);
    const memory_analysis_step = b.step("memory", "Run memory usage analysis");
    memory_analysis_step.dependOn(&run_memory_analysis.step);

    // ===== COMPREHENSIVE TEST RUNNER =====

    // Master test step that runs all test categories
    const all_tests_step = b.step("test-all", "Run all test categories");
    all_tests_step.dependOn(&run_unit_tests.step);
    all_tests_step.dependOn(&run_integration_tests.step);
    all_tests_step.dependOn(&run_performance_tests.step);
    all_tests_step.dependOn(&run_stress_tests.step);

    // ===== LEGACY COMPATIBILITY =====

    // Resource Monitor Demo
    const monitor_demo_exe = b.addExecutable(.{
        .name = "nendb-monitor-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/monitoring/demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
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

    // Note: nen-cli is a separate repository and should not be included in nen-db
    // The umbrella CLI functionality should be implemented in the nen-cli repository

    // Custom I/O module (our own implementation, no external dependencies)
    const custom_io_mod = b.createModule(.{ .root_source_file = b.path("src/io/io.zig"), .target = target, .optimize = optimize });

    // Nen-Net module for high-performance networking APIs
    const nen_net_mod = b.createModule(.{ .root_source_file = b.path("nen-net/src/lib.zig"), .target = target, .optimize = optimize });

    lib_mod.addImport("io", custom_io_mod);
    // Note: nen-net is only imported by executables that need networking, not by the core library
    monitoring_mod.addImport("io", custom_io_mod);
    exe.root_module.addImport("io", custom_io_mod);
    exe.root_module.addImport("nen-net", nen_net_mod);
    nen_cli.root_module.addImport("io", custom_io_mod);
    nen_cli.root_module.addImport("nen-net", nen_net_mod);

    // Networking Demo
    const networking_demo = b.addExecutable(.{
        .name = "networking-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/networking_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    networking_demo.root_module.addImport("nendb", lib_mod);
    networking_demo.root_module.addImport("nen-net", nen_net_mod);

    const run_networking_demo = b.addRunArtifact(networking_demo);
    const networking_demo_step = b.step("networking-demo", "Run networking demo");
    networking_demo_step.dependOn(&run_networking_demo.step);

    // Build-only step for CI (doesn't run the demo)
    const build_networking_demo_step = b.step("build-networking-demo", "Build networking demo executable");
    build_networking_demo_step.dependOn(&networking_demo.step);

    // NenCache module for conversation storage demo
    const nencache_mod = b.createModule(.{ .root_source_file = b.path("../nen-cache/src/main.zig"), .target = target, .optimize = optimize });

    // Conversation Storage Demo
    const conversation_demo = b.addExecutable(.{
        .name = "conversation-storage-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/conversation_storage_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    conversation_demo.root_module.addImport("nendb", lib_mod);
    conversation_demo.root_module.addImport("nencache", nencache_mod);

    const run_conversation_demo = b.addRunArtifact(conversation_demo);
    const conversation_demo_step = b.step("conversation-demo", "Run conversation storage demo");
    conversation_demo_step.dependOn(&run_conversation_demo.step);

    // HTTP Server executable using nen-net
    const server_exe = b.addExecutable(.{
        .name = "nendb-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/server_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    server_exe.root_module.addImport("nen-net", nen_net_mod);
    server_exe.root_module.addImport("algorithms", algorithms_mod);
    b.installArtifact(server_exe);

    const run_server = b.addRunArtifact(server_exe);
    const server_step = b.step("run-server", "Run NenDB HTTP Server");
    server_step.dependOn(&run_server.step);

    // HTTP API tests using nen-net
    const http_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/api/http_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    http_tests.root_module.addImport("nen-net", nen_net_mod);

    const run_http_tests = b.addRunArtifact(http_tests);
    const http_test_step = b.step("test-http", "Run HTTP API tests");
    http_test_step.dependOn(&run_http_tests.step);

    // ===== CROSS-COMPILATION TARGETS FOR RELEASES =====

    // Note: For now, we'll use the main target but add a note about cross-compilation
    // Users can build for specific targets using: zig build -Dtarget=x86_64-linux-gnu
    const cross_compile_step = b.step("cross-compile", "Build for all target platforms (use -Dtarget=<triple>)");
    cross_compile_step.dependOn(b.getInstallStep());

    // Add a note about available targets
    const note_step = b.addSystemCommand(&.{ "echo", "Available targets: x86_64-linux-gnu, x86_64-macos-gnu, aarch64-macos-gnu, x86_64-windows-gnu" });
    cross_compile_step.dependOn(&note_step.step);
}
