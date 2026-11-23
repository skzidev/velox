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

    const sdk = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/sdk/root.zig"),
    });

    const manifest_opts = b.addOptions();
    manifest_opts.addOption([]const u8, "version", @import("build.zig.zon").version);

    const serial_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/kernel/io/serial.zig"),
        .imports = &.{
            .{ .name = "jumptable", .module = jumptable },
        },
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
    kernel.addImport("sdk", sdk);
    kernel.addImport("serial", serial_mod);
    kernel.addOptions("manifest", manifest_opts);

    user.addImport("velox", sdk);

    sdk.addImport("jumptable", jumptable);

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

    const test_step = b.step("test", "Build on-hardware unit tests");
    const test_serial = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/kernel/io/serial.zig"),
        .imports = &.{
            .{ .name = "jumptable", .module = jumptable },
        },
    });
    const test_kernel = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/kernel/root.zig"),
    });
    test_kernel.addAnonymousImport("umm", .{ .root_source_file = b.path("src/umm/lib.zig") });
    test_kernel.addImport("code_root", b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("runner/runner.zig"),
        .imports = &.{
            .{ .name = "serial", .module = test_serial },
        },
    }));
    test_kernel.addImport("jumptable", jumptable);
    test_kernel.addImport("sdk", sdk);
    test_kernel.addImport("serial", test_serial);
    test_kernel.addOptions("manifest", manifest_opts);

    const tests = b.addTest(.{
        .root_module = test_kernel,
        .test_runner = .{ .path = b.path("runner/shim.zig"), .mode = .simple },
    });
    tests.root_module.addAssemblyFile(b.path("src/kernel/entry.s"));
    tests.root_module.addAssemblyFile(b.path("src/kernel/vectors/fault.s"));
    tests.root_module.addAssemblyFile(b.path("src/kernel/vectors/fiq.s"));
    tests.root_module.addAssemblyFile(b.path("src/kernel/vectors/svc.s"));
    tests.root_module.addAssemblyFile(b.path("src/kernel/vectors/irq.s"));
    tests.root_module.addAssemblyFile(b.path("src/kernel/vectors/vbar.s"));
    tests.setLinkerScript(b.path("linker.ld"));
    tests.entry = .{ .symbol_name = "_velox_boot" };

    const install_tests = b.addInstallArtifact(tests, .{ .dest_sub_path = "velox-test" });
    test_step.dependOn(&install_tests.step);

    const upload = b.step("upload", "Upload to the brain (requires cargo-v5)");
    const slot = b.option(u8, "slot", "V5 program slot (1-8)") orelse 8;
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
        b.fmt("{d}", .{slot}),
        "--file",
    });
    runCargoV5.addFileArg(exe.getEmittedBin());
    upload.dependOn(&runCargoV5.step);
}
