//! Build system definitions
const std = @import("std");

// This build script compiles the Velox Kernel for the VEX V5 brain.
// It outputs a proper memory-formatted file.

pub const ImportConfig = struct {
    name: []const u8,
    modName: []const u8,
    dep: *std.Build.Dependency,
};

/// Builds a user script
pub fn createVeloxExecutable(b: *std.Build, name: []const u8, usr_code_root: std.Build.LazyPath, usr_code_deps: []const ImportConfig) *std.Build.Step.Compile {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a9 },
    });

    const core_dependency = b.dependency("velox_core", .{});
    const core_module = b.createModule(.{
        .root_source_file = core_dependency.path("src/boot.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = core_module,
    });

    exe.entry = .{
        .symbol_name = "__velox_boot__",
    };

    // Velox-umm dependency
    const umm = b.dependency("velox_umm", .{});
    exe.root_module.addImport("velox_umm", umm.module("umm"));

    // Velox-jumptable dependency
    const jmptbl = b.dependency("velox_jumptable", .{});
    exe.root_module.addImport("velox_jumptable", jmptbl.module("velox_jumptable"));

    // Velox-sdk dependency
    const sdk = b.dependency("velox_sdk", .{});
    exe.root_module.addImport("velox_sdk", sdk.module("velox_sdk"));

    const addrs_ld_path = jmptbl.path("addrs.ld");
    const local_linker_path = core_dependency.path("linker.ld");

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

    const userCodeModule = b.createModule(.{ .target = target, .optimize = optimize, .root_source_file = usr_code_root });

    for (usr_code_deps) |dep| {
        userCodeModule.addImport(dep.name, dep.dep.module(dep.modName));
    }

    exe.root_module.addImport("user_code", userCodeModule);

    exe.setLinkerScript(dynamic_linker_script);

    return exe;
}

// This is derived from Vexide's list
pub const Icon = enum {
    vex_coding_studio,
    cool_x,
    question_mark,
    pizza,
    clawbot,
    robot,
    power_button,
    planets,
    alien,
    alien_in_ufo,
    cup_in_field,
    cup_and_ball,
    matlab,
    pros,
    robot_mesh,
    robot_mesh_cpp,
    robot_mesh_blockly,
    robot_mesh_flowol,
    robot_mesh_js,
    robot_mesh_py,
    code_file,
    vexcode_brackets,
    vexcode_blocks,
    vexcode_python,
    vexcode_cpp,

    pub fn string(self: Icon) []const u8 {
        return switch (self) {
            .vex_coding_studio => "vex-coding-studio",
            .cool_x => "cool-x",
            .question_mark => "question-mark",
            .pizza => "pizza",
            .clawbot => "clawbot",
            .robot => "robot",
            .power_button => "power-button",
            .planets => "planets",
            .alien => "alien",
            .alien_in_ufo => "alien-in-ufo",
            .cup_in_field => "cup-in-field",
            .cup_and_ball => "cup-and-ball",
            .matlab => "matlab",
            .pros => "pros",
            .robot_mesh => "robot-mesh",
            .robot_mesh_cpp => "robot-mesh-cpp",
            .robot_mesh_blockly => "robot-mesh-blockly",
            .robot_mesh_flowol => "robot-mesh-flowol",
            .robot_mesh_js => "robot-mesh-js",
            .robot_mesh_py => "robot-mesh-py",
            .code_file => "code-file",
            .vexcode_brackets => "vexcode-brackets",
            .vexcode_blocks => "vexcode-blocks",
            .vexcode_python => "vexcode-python",
            .vexcode_cpp => "vexcode-cpp",
        };
    }
};

pub fn addProgramUpload(b: *std.Build, name: []const u8, desc: []const u8, slot: u8, icon: Icon, file: std.Build.LazyPath) *std.Build.Step {
    if (slot < 1 or slot > 8) {
        std.debug.print("Cannot upload on slot {d}, it doesn't exist.", .{slot});
        @panic("Build halted.");
    }

    const upload = b.step("upload", "Upload to the V5 Brain");
    const upload_command = b.addSystemCommand(&.{
        "cargo-v5",
        "v5",
        "upload",
        "--name",
        name,
        "--description",
        desc,
        "--slot",
        b.fmt("{d}", .{slot}),
        "--icon",
        icon.string(),
        "--file",
    });
    upload_command.addFileArg(file);
    upload.dependOn(&upload_command.step);
    return upload;
}

/// Builds the raw kernel itself
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

    // Velox-umm dependency
    const umm = b.dependency("velox_umm", .{});
    exe.root_module.addImport("velox_umm", umm.module("umm"));

    // Velox-jumptable dependency
    const jmptbl = b.dependency("velox_jumptable", .{});
    exe.root_module.addImport("velox_jumptable", jmptbl.module("velox_jumptable"));

    // Velox-sdk dependency
    const sdk = b.dependency("velox_sdk", .{});
    exe.root_module.addImport("velox_sdk", sdk.module("velox_sdk"));

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

    const user_code = b.createModule(.{ .root_source_file = b.path("mock/user_code.zig"), .target = target, .optimize = optimize });

    user_code.addImport("velox_sdk", sdk.module("velox_sdk"));
    user_code.addImport("velox_jumptable", jmptbl.module("velox_jumptable"));

    exe.root_module.addImport("user_code", user_code);

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
