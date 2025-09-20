// NenDB Distributed Build Configuration
// Optimized for multi-user, networked applications

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target and optimization options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create dependencies
    var nen_core: ?*std.Build.Module = null;
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
    }

    // Create the distributed library module
    const lib_mod = b.addModule("nendb-distributed", .{
        .root_source_file = b.path("src/distributed.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies
    if (nen_core) |nc| lib_mod.addImport("nen-core", nc);
    if (nen_io) |ni| lib_mod.addImport("nen-io", ni);
    if (nen_json) |nj| lib_mod.addImport("nen-json", nj);
    if (nen_net) |nn| lib_mod.addImport("nen-net", nn);

    // Distributed node executable
    const exe = b.addExecutable(.{
        .name = "nendb-distributed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/distributed_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("nendb-distributed", lib_mod);
    b.installArtifact(exe);

    // Distributed library for linking
    const lib = b.addStaticLibrary(.{
        .name = "nendb-distributed",
        .root_source_file = b.path("src/distributed.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (nen_core) |nc| lib.root_module.addImport("nen-core", nc);
    if (nen_io) |ni| lib.root_module.addImport("nen-io", ni);
    if (nen_json) |nj| lib.root_module.addImport("nen-json", nj);
    if (nen_net) |nn| lib.root_module.addImport("nen-net", nn);
    b.installArtifact(lib);

    // Build steps
    const distributed_step = b.step("distributed", "Build the distributed NenDB");
    distributed_step.dependOn(&exe.step);
    distributed_step.dependOn(&lib.step);

    // Test step
    const test_step = b.step("test-distributed", "Run distributed NenDB tests");
    const tests = b.addTest(.{
        .root_source_file = b.path("src/distributed.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("nendb-distributed", lib_mod);
    test_step.dependOn(&tests.step);

    // Cluster management tools
    const cluster_tools = [_]struct { name: []const u8, source: []const u8 }{
        .{ .name = "cluster-manager", .source = "tools/cluster_manager.zig" },
        .{ .name = "load-balancer", .source = "tools/load_balancer.zig" },
        .{ .name = "monitoring", .source = "tools/monitoring.zig" },
        .{ .name = "backup-tool", .source = "tools/backup_tool.zig" },
    };

    for (cluster_tools) |tool| {
        if (std.fs.cwd().openFile(tool.source, .{}) catch null) |f| {
            _ = f.close();
            const tool_exe = b.addExecutable(.{
                .name = tool.name,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(tool.source),
                    .target = target,
                    .optimize = optimize,
                }),
            });
            tool_exe.root_module.addImport("nendb-distributed", lib_mod);
            b.installArtifact(tool_exe);
        }
    }

    // Example applications
    const examples = [_]struct { name: []const u8, source: []const u8 }{
        .{ .name = "enterprise-app", .source = "examples/enterprise_app.zig" },
        .{ .name = "social-network", .source = "examples/social_network.zig" },
        .{ .name = "real-time-analytics", .source = "examples/real_time_analytics.zig" },
        .{ .name = "ai-training", .source = "examples/ai_training.zig" },
    };

    for (examples) |example| {
        if (std.fs.cwd().openFile(example.source, .{}) catch null) |f| {
            _ = f.close();
            const example_exe = b.addExecutable(.{
                .name = example.name,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(example.source),
                    .target = target,
                    .optimize = optimize,
                }),
            });
            example_exe.root_module.addImport("nendb-distributed", lib_mod);
            b.installArtifact(example_exe);
        }
    }
}
