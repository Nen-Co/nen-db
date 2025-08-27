// Copyright (c) 2025 Maysara, All rights reserved.
//
// repo : https://github.com/Super-ZIG/io
// docs : https://super-zig.github.io/io
//
// owner : https://github.com/maysara-elshewehy
// email : maysara.elshewehy@gmail.com
//
// Made with ❤️ by Maysara



// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const Build = @import("std").Build;

// ╚══════════════════════════════════════════════════════════════════════════════════╝



// ╔══════════════════════════════════════ BUILD ═════════════════════════════════════╗

    pub fn build(b: *Build) void {
        const lib_mod           = b.createModule(.{
            .root_source_file   = b.path("lib/io.zig"),
            .target             = b.standardTargetOptions(.{}),
            .optimize           = b.standardOptimizeOption(.{}),
        });

        const lib               = b.addLibrary(.{
            .linkage            = .static,
            .name               = "io",
            .root_module        = lib_mod,
        });

        b.installArtifact(lib);

        const lib_tests         = b.addTest(.{
            .root_module        = lib_mod,
        });

        const run_lib_tests     = b.addRunArtifact(lib_tests);

        const test_step         = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_tests.step);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════╝