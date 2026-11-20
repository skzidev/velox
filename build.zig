const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{
            .explicit = &std.Target.arm.cpu.cortex_a9,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const jumptable = b.dependency("velox_jumptable", .{}).module("velox_jumptable");

    // user code
    const user = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("mock/user_code.zig"),
    });

    // kernel code
    const kernel = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/kernel/root.zig"),
    });
    kernel.addAnonymousImport("umm", .{ .root_source_file = b.path("src/umm/lib.zig") });
    kernel.addImport("code_root", user);
    kernel.addImport("jumptable", jumptable);

    // add asm
    kernel.addAssemblyFile(b.path("src/kernel/entry.s"));
    kernel.addAssemblyFile(b.path("src/kernel/vectors/fault.s"));
    kernel.addAssemblyFile(b.path("src/kernel/vectors/fiq.s"));
    kernel.addAssemblyFile(b.path("src/kernel/vectors/svc.s"));
    kernel.addAssemblyFile(b.path("src/kernel/vectors/irq.s"));
    kernel.addAssemblyFile(b.path("src/kernel/vectors/vbar.s"));

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
        "--slot",
        "8",
        "--file",
    });
    runCargoV5.addFileArg(exe.getEmittedBin());
    upload.dependOn(&runCargoV5.step);
}
