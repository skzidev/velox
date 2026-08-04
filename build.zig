//! Build system definitions
const std = @import("std");

// This build script compiles the Zeolite Kernel for the VEX V5 brain.
// It outputs a proper memory-formatted file.

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a9 },
    });

    const exe = b.addExecutable(.{
        .name = "kernel.bin",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/boot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.entry = .{
        .symbol_name = "__zeolite_boot__",
    };

    // zeolite-umm dependency
    const umm = b.dependency("zeolite_umm", .{});
    exe.root_module.addImport("zeolite_umm", umm.module("umm"));

    // zeolite-jumptable dependency
    const jmptbl = b.dependency("zeolite_jumptable", .{});
    exe.root_module.addImport("zeolite_jumptable", jmptbl.module("zeolite_jumptable"));

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

    const upload = b.step("upload", "Upload to the VEX V5 brain");
    const upload_cmd = b.addSystemCommand(&.{
        "cargo-v5",
        "v5",
        "upload",
        "--name",
        "Zeolite Kernel",
        "--description",
        "The Zeolite Kernel",
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
