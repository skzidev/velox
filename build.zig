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

    // add asm
    kernel.addAssemblyFile(b.path("src/kernel/entry.s"));

    // create executable
    const exe = b.addExecutable(.{
        .root_module = kernel,
        .name = "velox",
    });

    _ = exe.addObjCopy(.{
        .format = .binary,
    });

    exe.setLinkerScript(b.path("linker.ld"));
    exe.entry = .{ .symbol_name = "_velox_boot" };
    b.installArtifact(exe);

    b.default_step.dependOn(&exe.step);
}
