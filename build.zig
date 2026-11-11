const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{
            .explicit = &std.Target.arm.cpu.cortex_a9,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    // kernel code
    const kernel = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/kernel/root.zig"),
    });
    kernel.addAnonymousImport("umm", .{ .root_source_file = b.path("src/umm/lib.zig") });
    kernel.addAnonymousImport("code_root", .{ .root_source_file = b.path("mock/user_code.zig") });
    kernel.addImport("jumptable", b.dependency("velox_jumptable", .{}).module("velox_jumptable"));

    // add asm
    kernel.addAssemblyFile(b.path("src/kernel/entry.s"));

    // create executable
    const exe = b.addExecutable(.{
        .root_module = kernel,
        .name = "velox",
    });

    exe.setLinkerScript(b.path("linker.ld"));
    exe.entry = .{ .symbol_name = "_velox_boot" };

    b.installArtifact(exe);
    b.default_step.dependOn(&exe.step);

    const upload = b.step("upload", "Upload to the brain");
    const runCargoV5 = b.addSystemCommand(&.{
        "cargo",
        "v5",
        "upload",
        "--name",
        "Velox",
        "-d",
        "Made with Velox",
        "--upload-strategy",
        "monolith",
        "--file",
    });
    runCargoV5.addFileArg(exe.getEmittedBin());
    upload.dependOn(&runCargoV5.step);
}
