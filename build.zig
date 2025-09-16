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

    // Main executable
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

    // Examples
    const networking_demo = b.addExecutable(.{
        .name = "networking-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/networking_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    networking_demo.root_module.addImport("nendb", lib_mod);
    b.installArtifact(networking_demo);

    // Examples step
    const examples_step = b.step("examples", "Build all examples");
    examples_step.dependOn(&networking_demo.step);
}
