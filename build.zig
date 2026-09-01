const std = @import("std");

const VeloxModules = struct {
    core: *std.Build.Module,
    umm: *std.Build.Module,
    sdk: *std.Build.Module,
    jumptable: *std.Build.Dependency,
};

fn generateLinkerScript(b: *std.Build, jumptable: *std.Build.Dependency) !std.Build.LazyPath {
    // initialize IO for linker script read
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    defer threaded.deinit();

    // read the linker scripts into ls1 (velox) and ls2 (jumptable)
    const veloxLinkerScript = try std.Io.Dir.cwd().openFile(io, "linker.ld", .{ .mode = .read_only });
    const jmptblLinkerScript = try std.Io.Dir.cwd().openFile(io, jumptable.path("addrs.ld").getPath(b), .{ .mode = .read_only });
    const ls1 = try b.allocator.alloc(u8, try veloxLinkerScript.length(io));
    const ls2 = try b.allocator.alloc(u8, try jmptblLinkerScript.length(io));
    _ = try veloxLinkerScript.readPositionalAll(io, ls1, 0);
    _ = try jmptblLinkerScript.readPositionalAll(io, ls2, 0);
    veloxLinkerScript.close(io);
    jmptblLinkerScript.close(io);

    // write the linker script
    const ls = b.addWriteFiles();
    return ls.add("ls.ld", b.fmt("{s}\n{s}", .{ ls1, ls2 }));
}

fn getVeloxModules(b: *std.Build, optimize: std.builtin.OptimizeMode) VeloxModules {
    const target = getV5Target(b);

    const velox = b.createModule(.{ .root_source_file = b.path("./src/kernel/boot.zig"), .target = target, .optimize = optimize });
    const umm = b.createModule(.{ .root_source_file = b.path("./src/umm/lib.zig"), .target = target, .optimize = optimize });
    const sdk = b.addModule("velox_sdk", .{ .root_source_file = b.path("./src/sdk/root.zig"), .target = target, .optimize = optimize });
    const jumptable = b.dependency("velox_jumptable", .{});

    velox.addImport("velox_sdk", sdk);
    velox.addImport("velox_umm", umm);
    velox.addImport("velox_jumptable", jumptable.module("velox_jumptable"));
    const manifest = b.createModule(.{
        .root_source_file = b.path("build.zig.zon"),
        .optimize = optimize,
        .target = target,
    });
    velox.addImport("manifest", manifest);
    sdk.addImport("velox_jumptable", jumptable.module("velox_jumptable"));

    return .{
        .core = velox,
        .umm = umm,
        .sdk = sdk,
        .jumptable = jumptable,
    };
}

pub fn addExecutable(
    b: *std.Build,
    code_root: std.Build.LazyPath,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Step.Compile {
    const veloxModules = getVeloxModules(b, optimize);
    const velox = veloxModules.core;
    const sdk = veloxModules.sdk;
    const jumptable = veloxModules.jumptable;
    const user_code = b.createModule(.{
        .root_source_file = code_root,
        .optimize = optimize,
        .target = getV5Target(b),
    });

    velox.addImport("user_code", user_code);

    user_code.addImport("velox", sdk);

    const exe = b.addExecutable(.{
        .root_module = velox,
        .name = "velox",
        .use_llvm = true,
    });
    exe.entry = .{ .symbol_name = "__velox_boot__" };

    const ls = try generateLinkerScript(b, jumptable);
    exe.setLinkerScript(ls);

    b.installArtifact(exe);

    return exe;
}

pub const VeloxBuildError = error{NonexistantSlot};

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

pub fn addUpload(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    name: []const u8,
    description: []const u8,
    icon: Icon,
    slot: u8,
) !*std.Build.Step.Run {
    if (slot < 1 or slot > 8) {
        return VeloxBuildError.NonexistantSlot;
    }
    const copy = exe.addObjCopy(.{ .format = .bin });
    const cmd = b.addSystemCommand(&.{
        "cargo-v5",
        "v5",
        "upload",
        "--name",
        name,
        "--description",
        description,
        "--slot",
        b.fmt("{d}", .{slot}),
        "--icon",
        icon.string(),
        "--file",
    });
    cmd.addFileArg(copy.getOutput());
    cmd.step.dependOn(&copy.step);
    return cmd;
}

fn getV5Target(b: *std.Build) std.Build.ResolvedTarget {
    return b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .os_tag = .freestanding,
        .abi = .eabihf,
        .cpu_model = .{
            .explicit = &std.Target.arm.cpu.cortex_a9,
        },
    });
}

fn createTests(b: *std.Build, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const veloxModules = getVeloxModules(b, optimize);
    const velox = veloxModules.core;

    const runnerModule = b.createModule(.{
        .root_source_file = b.path("./runner/runner.zig"),
        .optimize = optimize,
        .target = getV5Target(b),
    });
    runnerModule.addImport("velox", veloxModules.sdk);

    velox.addImport("user_code", runnerModule);

    const testing = b.addTest(.{
        .root_module = velox,
        .test_runner = .{
            .path = b.path("runner/shim.zig"),
            .mode = .simple,
        },
    });

    testing.entry = .{ .symbol_name = "__velox_boot__" };

    const ls = try generateLinkerScript(b, veloxModules.jumptable);
    testing.setLinkerScript(ls);

    return testing;
}

pub fn build(b: *std.Build) !void {
    const optimize = std.Build.standardOptimizeOption(b, .{});

    const exe = try addExecutable(b, b.path("mock/user_code.zig"), optimize);
    b.default_step.dependOn(&exe.step);

    const upload = b.step("upload", "Upload the kernel to the brain");
    const cmd = try addUpload(b, exe, "Velox", "Velox Kernel", .matlab, 8);
    upload.dependOn(b.default_step);
    upload.dependOn(&cmd.step);

    const testgen = b.step("test", "Build a test runner and upload it to the brain");
    const testing = try createTests(b, optimize);
    const uploadTest = try addUpload(b, testing, "Velox Tests", "Tests for the Velox Runtime", .code_file, 8);
    testgen.dependOn(&testing.step);
    testgen.dependOn(&uploadTest.step);
}
