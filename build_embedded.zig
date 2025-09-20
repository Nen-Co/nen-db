// NenDB Embedded Build Configuration
// Optimized for single-user, local applications

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

    // Create the embedded library module
    const lib_mod = b.addModule("nendb-embedded", .{
        .root_source_file = b.path("src/embedded.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies
    if (nen_core) |nc| lib_mod.addImport("nen-core", nc);
    if (nen_io) |ni| lib_mod.addImport("nen-io", ni);
    if (nen_json) |nj| lib_mod.addImport("nen-json", nj);

    // Embedded executable
    const exe = b.addExecutable(.{
        .name = "nendb-embedded",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/embedded_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("nendb-embedded", lib_mod);
    b.installArtifact(exe);

    // Embedded library for linking
    const lib = b.addStaticLibrary(.{
        .name = "nendb-embedded",
        .root_source_file = b.path("src/embedded.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (nen_core) |nc| lib.root_module.addImport("nen-core", nc);
    if (nen_io) |ni| lib.root_module.addImport("nen-io", ni);
    if (nen_json) |nj| lib.root_module.addImport("nen-json", nj);
    b.installArtifact(lib);

    // Build steps
    const embedded_step = b.step("embedded", "Build the embedded NenDB");
    embedded_step.dependOn(&exe.step);
    embedded_step.dependOn(&lib.step);

    // Test step
    const test_step = b.step("test-embedded", "Run embedded NenDB tests");
    const tests = b.addTest(.{
        .root_source_file = b.path("src/embedded.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("nendb-embedded", lib_mod);
    test_step.dependOn(&tests.step);

    // Example applications
    const examples = [_]struct { name: []const u8, source: []const u8 }{
        .{ .name = "desktop-app", .source = "examples/desktop_app.zig" },
        .{ .name = "mobile-app", .source = "examples/mobile_app.zig" },
        .{ .name = "iot-device", .source = "examples/iot_device.zig" },
        .{ .name = "development-tool", .source = "examples/development_tool.zig" },
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
            example_exe.root_module.addImport("nendb-embedded", lib_mod);
            b.installArtifact(example_exe);
        }
    }
}
