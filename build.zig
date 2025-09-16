const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create dependencies in the right order (nen-core first, then others that depend on it)
    const nen_core = b.addModule("nen-core", .{
        .root_source_file = b.path("../nen-core/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const nen_io = b.addModule("nen-io", .{
        .root_source_file = b.path("../nen-io/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const nen_json = b.addModule("nen-json", .{
        .root_source_file = b.path("../nen-json/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const nen_net = b.addModule("nen-net", .{
        .root_source_file = b.path("../nen-net/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    // nen-net depends on nen-core, nen-io, and nen-json
    nen_net.addImport("nen-core", nen_core);
    nen_net.addImport("nen-io", nen_io);
    nen_net.addImport("nen-json", nen_json);

    // Main library module - add all dependencies to it
    const lib_mod = b.addModule("nendb", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("nen-core", nen_core);
    lib_mod.addImport("nen-io", nen_io);
    lib_mod.addImport("nen-json", nen_json);
    lib_mod.addImport("nen-net", nen_net);

    // Main executable using full-featured main with Terminal output and CLI
    const exe = b.addExecutable(.{
        .name = "nendb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("nendb", lib_mod);
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run NenDB");
    run_step.dependOn(&run_cmd.step);

    // Data test example
    const data_test = b.addExecutable(.{
        .name = "data-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/data_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    data_test.root_module.addImport("nendb", lib_mod);
    b.installArtifact(data_test);

    // Large dataset test
    const large_dataset_test = b.addExecutable(.{
        .name = "large-dataset-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/large_dataset_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    large_dataset_test.root_module.addImport("nendb", lib_mod);
    b.installArtifact(large_dataset_test);

    // Data test step
    const data_test_run = b.addRunArtifact(data_test);
    data_test_run.step.dependOn(b.getInstallStep());
    const data_test_step = b.step("data-test", "Run comprehensive data tests");
    data_test_step.dependOn(&data_test_run.step);

    // Large dataset test step
    const large_test_run = b.addRunArtifact(large_dataset_test);
    large_test_run.step.dependOn(b.getInstallStep());
    const large_test_step = b.step("large-test", "Run large dataset performance tests");
    large_test_step.dependOn(&large_test_run.step);

    // Kaggle dataset test executable
    const kaggle_test = b.addExecutable(.{
        .name = "kaggle-dataset-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/kaggle_dataset_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add dependencies to kaggle test
    kaggle_test.root_module.addImport("nendb", lib_mod);
    kaggle_test.root_module.addImport("nen-core", nen_core);
    kaggle_test.root_module.addImport("nen-io", nen_io);
    kaggle_test.root_module.addImport("nen-json", nen_json);
    kaggle_test.root_module.addImport("nen-net", nen_net);
    b.installArtifact(kaggle_test);

    // Kaggle test step
    const kaggle_test_run = b.addRunArtifact(kaggle_test);
    kaggle_test_run.step.dependOn(b.getInstallStep());
    const kaggle_test_step = b.step("kaggle-test", "Run Kaggle knowledge graph dataset tests");
    kaggle_test_step.dependOn(&kaggle_test_run.step);

    // Comprehensive API test executable
    const api_test = b.addExecutable(.{
        .name = "comprehensive-api-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/comprehensive_api_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add dependencies to API test
    api_test.root_module.addImport("nendb", lib_mod);
    api_test.root_module.addImport("nen-core", nen_core);
    api_test.root_module.addImport("nen-io", nen_io);
    api_test.root_module.addImport("nen-json", nen_json);
    api_test.root_module.addImport("nen-net", nen_net);
    b.installArtifact(api_test);

    // API test step
    const api_test_run = b.addRunArtifact(api_test);
    api_test_run.step.dependOn(b.getInstallStep());
    const api_test_step = b.step("api-test", "Run comprehensive API functionality tests");
    api_test_step.dependOn(&api_test_run.step);
    // WASM build step
    const wasm_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const wasm_opt = optimize;
    const wasm_exe = b.addExecutable(.{
        .name = "nendb-wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = wasm_target,
            .optimize = wasm_opt,
        }),
    });
    // Import the main library into the wasm root module so symbols resolve when building
    wasm_exe.root_module.addImport("nendb", lib_mod);
    // Do not call linkLibC or linkLibCpp; default is no linking
    b.installArtifact(wasm_exe);
    const wasm_build_step = b.step("wasm", "Build NenDB WASM module");
    wasm_build_step.dependOn(&wasm_exe.step);
    // Output will be wasm/nendb-wasm.wasm

    // Cross-platform native targets
    const macos_x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .macos });
    const macos_arm = b.resolveTargetQuery(.{ .cpu_arch = .aarch64, .os_tag = .macos });
    const linux_x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux });
    const windows_x86 = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows });

    const mac_x86_exe = b.addExecutable(.{
        .name = "nendb-macos-x86_64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = macos_x86,
            .optimize = optimize,
        }),
    });
    mac_x86_exe.root_module.addImport("nendb", lib_mod);
    b.installArtifact(mac_x86_exe);

    const mac_arm_exe = b.addExecutable(.{
        .name = "nendb-macos-aarch64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = macos_arm,
            .optimize = optimize,
        }),
    });
    mac_arm_exe.root_module.addImport("nendb", lib_mod);
    b.installArtifact(mac_arm_exe);

    const linux_exe = b.addExecutable(.{
        .name = "nendb-linux-x86_64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = linux_x86,
            .optimize = optimize,
        }),
    });
    linux_exe.root_module.addImport("nendb", lib_mod);
    b.installArtifact(linux_exe);

    const win_exe = b.addExecutable(.{
        .name = "nendb-windows-x86_64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = windows_x86,
            .optimize = optimize,
        }),
    });
    win_exe.root_module.addImport("nendb", lib_mod);
    b.installArtifact(win_exe);

    // Aggregate build-all step
    const build_all_step = b.step("build-all", "Build all platform artifacts (macOS, Linux, Windows, WASM)");
    build_all_step.dependOn(&wasm_exe.step);
    build_all_step.dependOn(&mac_x86_exe.step);
    build_all_step.dependOn(&mac_arm_exe.step);
    build_all_step.dependOn(&linux_exe.step);
    build_all_step.dependOn(&win_exe.step);
}
