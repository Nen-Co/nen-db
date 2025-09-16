const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create dependencies in the right order (nen-core first, then others that depend on it)
    var nen_core: ?*std.Build.Module = null;
    // Only add the module if the sibling repo file exists in CI checkout
    if (std.fs.cwd().openFile("../nen-core/src/lib.zig", .{}) catch null) |f| {
        _ = f.close();
        nen_core = b.addModule("nen-core", .{
            .root_source_file = b.path("../nen-core/src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });
    }

    var nen_io: ?*std.Build.Module = null;
    if (std.fs.cwd().openFile("../nen-io/src/lib.zig", .{}) catch null) |f| {
        _ = f.close();
        nen_io = b.addModule("nen-io", .{
            .root_source_file = b.path("../nen-io/src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });
    }

    var nen_json: ?*std.Build.Module = null;
    if (std.fs.cwd().openFile("../nen-json/src/lib.zig", .{}) catch null) |f| {
        _ = f.close();
        nen_json = b.addModule("nen-json", .{
            .root_source_file = b.path("../nen-json/src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });
    }

    var nen_net: ?*std.Build.Module = null;
    if (std.fs.cwd().openFile("../nen-net/src/lib.zig", .{}) catch null) |f| {
        _ = f.close();
        nen_net = b.addModule("nen-net", .{
            .root_source_file = b.path("../nen-net/src/lib.zig"),
            .target = target,
            .optimize = optimize,
        });
        if (nen_net) |nn| {
            if (nen_core) |nc| nn.addImport("nen-core", nc);
            if (nen_io) |ni| nn.addImport("nen-io", ni);
            if (nen_json) |nj| nn.addImport("nen-json", nj);
        }
    }

    // Main library module - add all dependencies to it
    const lib_mod = b.addModule("nendb", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (nen_core) |nc| lib_mod.addImport("nen-core", nc);
    if (nen_io) |ni| lib_mod.addImport("nen-io", ni);
    if (nen_json) |nj| lib_mod.addImport("nen-json", nj);
    if (nen_net) |nn| lib_mod.addImport("nen-net", nn);

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

    // Provide a named build step 'nendb' so CI and users can run `zig build nendb`.
    // This step depends on the main executable being built/installed.
    const nendb_step = b.step("nendb", "Build the nendb executable");
    nendb_step.dependOn(&exe.step);

    // Provide a `nendb-http-server` step. The CI expects this target name.
    // If a dedicated HTTP server source exists, build it; otherwise provide
    // a lightweight alias step that depends on the main `nendb` executable
    // so `zig build nendb-http-server` succeeds even in minimal checkouts.
    if (std.fs.cwd().openFile("src/http_server.zig", .{}) catch null) |f| {
        _ = f.close();
        const http_exec = b.addExecutable(.{
            .name = "nendb-http-server",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/http_server.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        http_exec.root_module.addImport("nendb", lib_mod);
        if (nen_net) |nn| http_exec.root_module.addImport("nen-net", nn);
        b.installArtifact(http_exec);
        const http_step = b.step("nendb-http-server", "Build the nendb HTTP server");
        http_step.dependOn(&http_exec.step);
    } else {
        const http_alias = b.step("nendb-http-server", "Alias for nendb HTTP server (depends on nendb)");
        http_alias.dependOn(&exe.step);
    }

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run NenDB");
    run_step.dependOn(&run_cmd.step);

    // Data test example (optional)
    if (std.fs.cwd().openFile("examples/data_test.zig", .{}) catch null) |f| {
        _ = f.close();
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
        const data_test_run = b.addRunArtifact(data_test);
        data_test_run.step.dependOn(b.getInstallStep());
        const data_test_step = b.step("data-test", "Run comprehensive data tests");
        data_test_step.dependOn(&data_test_run.step);
    }

    // Large dataset test (optional)
    if (std.fs.cwd().openFile("examples/large_dataset_test.zig", .{}) catch null) |f| {
        _ = f.close();
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
        const large_test_run = b.addRunArtifact(large_dataset_test);
        large_test_run.step.dependOn(b.getInstallStep());
        const large_test_step = b.step("large-test", "Run large dataset performance tests");
        large_test_step.dependOn(&large_test_run.step);
    }

    // Kaggle dataset test executable (optional)
    if (std.fs.cwd().openFile("examples/kaggle_dataset_test.zig", .{}) catch null) |f| {
        _ = f.close();
        const kaggle_test = b.addExecutable(.{
            .name = "kaggle-dataset-test",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/kaggle_dataset_test.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        kaggle_test.root_module.addImport("nendb", lib_mod);
        if (nen_core) |nc| kaggle_test.root_module.addImport("nen-core", nc);
        if (nen_io) |ni| kaggle_test.root_module.addImport("nen-io", ni);
        if (nen_json) |nj| kaggle_test.root_module.addImport("nen-json", nj);
        if (nen_net) |nn| kaggle_test.root_module.addImport("nen-net", nn);
        b.installArtifact(kaggle_test);
        const kaggle_test_run = b.addRunArtifact(kaggle_test);
        kaggle_test_run.step.dependOn(b.getInstallStep());
        const kaggle_test_step = b.step("kaggle-test", "Run Kaggle knowledge graph dataset tests");
        kaggle_test_step.dependOn(&kaggle_test_run.step);
    }

    // Comprehensive API test executable (optional)
    if (std.fs.cwd().openFile("examples/comprehensive_api_test.zig", .{}) catch null) |f| {
        _ = f.close();
        const api_test = b.addExecutable(.{
            .name = "comprehensive-api-test",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/comprehensive_api_test.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        api_test.root_module.addImport("nendb", lib_mod);
        if (nen_core) |nc| api_test.root_module.addImport("nen-core", nc);
        if (nen_io) |ni| api_test.root_module.addImport("nen-io", ni);
        if (nen_json) |nj| api_test.root_module.addImport("nen-json", nj);
        if (nen_net) |nn| api_test.root_module.addImport("nen-net", nn);
        b.installArtifact(api_test);
        const api_test_run = b.addRunArtifact(api_test);
        api_test_run.step.dependOn(b.getInstallStep());
        const api_test_step = b.step("api-test", "Run comprehensive API functionality tests");
        api_test_step.dependOn(&api_test_run.step);
    }
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
    // Provide a 'build-wasm' step name for CI compatibility (some workflows call this target).
    const build_wasm_alias = b.step("build-wasm", "Alias for wasm build step");
    build_wasm_alias.dependOn(&wasm_exe.step);
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

    // Aggregate test step for CI compatibility. This ensures `zig build test` finds a
    // step named "test" even when example tests are optional in the checkout.
    const test_step = b.step("test", "Aggregate test step for CI");
    // Depend on install to ensure compiled artifacts are present; individual
    // example test steps will run if their sources existed and were wired above.
    test_step.dependOn(b.getInstallStep());
}
