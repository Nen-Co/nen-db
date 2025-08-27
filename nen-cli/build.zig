const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{ .name = "nen", .root_source_file = b.path("nen-cli/src/main.zig"), .target = target, .optimize = optimize });

    // Link graph module (reuse graphdb) for status command
    const graph_mod = b.addModule("nendb_graph", .{ .root_source_file = b.path("src/graphdb.zig"), .target = target, .optimize = optimize });
    exe.root_module.addImport("nendb_graph", graph_mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run-nen", "Run unified nen CLI");
    run_step.dependOn(&run_cmd.step);
}
