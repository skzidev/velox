//! Build system definitions
const std = @import("std");

// This build script compiles the Velox Kernel for the VEX V5 brain.
// It outputs a proper memory-formatted file.

pub fn createVeloxExecutable(b: *std.Build, name: []const u8, usr_code_root: std.Build.LazyPath) *std.Build.Step.Compile {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a9 },
    });

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/boot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.entry = .{
        .symbol_name = "__velox_boot__",
    };

    // Volex-umm dependency
    const umm = b.dependency("velox_umm", .{});
    exe.root_module.addImport("velox_umm", umm.module("umm"));

    // Volex-jumptable dependency
    const jmptbl = b.dependency("velox_jumptable", .{});
    exe.root_module.addImport("velox_jumptable", jmptbl.module("velox_jumptable"));

    const addrs_ld_path = jmptbl.path("addrs.ld");
    const local_linker_path = b.path("linker.ld");

    const stitch_cmd = b.addSystemCommand(&.{
        "python3", "-c",
        \\import sys
        \\out = open(sys.argv[3], 'w')
        \\out.write(open(sys.argv[1], 'r').read() + '\n\n' + open(sys.argv[2], 'r').read())
        \\out.close()
    });

    stitch_cmd.addFileArg(addrs_ld_path); // sys.argv[1]
    stitch_cmd.addFileArg(local_linker_path); // sys.argv[2]

    const dynamic_linker_script = stitch_cmd.addOutputFileArg("stitched_linker.ld"); // sys.argv[3]

    exe.setLinkerScript(dynamic_linker_script);

    exe.root_module.addAnonymousImport("user_code", .{
        .root_source_file = usr_code_root,
        .target = target,
        .optimize = optimize,
    });

    return exe;
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a9 },
    });

    const exe = b.addExecutable(.{
        .name = "velox.bin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/boot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.entry = .{
        .symbol_name = "__velox_boot__",
    };

    // Volex-umm dependency
    const umm = b.dependency("velox_umm", .{});
    exe.root_module.addImport("velox_umm", umm.module("umm"));

    // Volex-jumptable dependency
    const jmptbl = b.dependency("velox_jumptable", .{});
    exe.root_module.addImport("velox_jumptable", jmptbl.module("velox_jumptable"));

    const addrs_ld_path = jmptbl.path("addrs.ld");
    const local_linker_path = b.path("linker.ld");

    const stitch_cmd = b.addSystemCommand(&.{
        "python3", "-c",
        \\import sys
        \\out = open(sys.argv[3], 'w')
        \\out.write(open(sys.argv[1], 'r').read() + '\n\n' + open(sys.argv[2], 'r').read())
        \\out.close()
    });

    stitch_cmd.addFileArg(addrs_ld_path); // sys.argv[1]
    stitch_cmd.addFileArg(local_linker_path); // sys.argv[2]

    const dynamic_linker_script = stitch_cmd.addOutputFileArg("stitched_linker.ld"); // sys.argv[3]

    exe.setLinkerScript(dynamic_linker_script);

    const bin = exe.addObjCopy(.{
        .format = .bin,
    });

    b.installArtifact(exe);

    b.default_step.dependOn(&exe.step);

    // This should be replaced with a Velox CLI, but that hasn't been developed yet
    // (or this project uses a version from when a Velox CLI didn't exist)
    const upload = b.step("upload", "Upload to the VEX V5 brain");
    const upload_cmd = b.addSystemCommand(&.{
        "cargo-v5",
        "v5",
        "upload",
        "--name",
        "Velox Core",
        "--description",
        "Velox Program",
        "--icon",
        "cup-in-field",
        "--slot",
        "8",
        "--file",
    });
    upload_cmd.addFileArg(bin.getOutput());

    upload_cmd.step.dependOn(&exe.step);
    upload.dependOn(&upload_cmd.step);
}
