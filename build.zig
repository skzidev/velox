//! # Velox Build System
//!
//! Provides the Zig build script for compiling Velox firmware images
//! for the VEX V5 Brain (ARM Cortex-A9, freestanding, EABI hard-float).
//!
//! ## Build steps
//!
//! - `zig build` — compiles the mock user program into a `.bin` firmware
//!   image.
//! - `zig build upload` — builds and uploads to slot 8 on the V5 Brain
//!   via `cargo-v5`.
//! - `zig build test` — builds the on-hardware test runner and uploads it.
//!
//! ## Usage from external projects
//!
//! Call [`addExecutable`] to create a Velox firmware image from your own
//! user code, and [`addUpload`] to generate an upload step.

const std = @import("std");

/// Bundles the three core Velox modules and the jumptable dependency.
/// Returned by [`getVeloxModules`].
const VeloxModules = struct {
    /// The `velox_core` module (kernel / boot).
    core: *std.Build.Module,
    /// The `velox_umm` module (heap allocator).
    umm: *std.Build.Module,
    /// The `velox_sdk` module (device drivers, I/O, units).
    sdk: *std.Build.Module,
    /// The `velox_jumptable` dependency (VEXos firmware bindings).
    jumptable: *std.Build.Dependency,
};

/// Concatenates the Velox `linker.ld` and the jumptable `addrs.ld` into
/// a single linker script (`ls.ld`) that the linker step consumes.
///
/// The resulting script defines the memory layout (USER_RAM at
/// `0x03800000`), stack regions, and section placements.
fn generateLinkerScript(b: *std.Build, velox_root: std.Build.LazyPath, jumptable: *std.Build.Dependency) !std.Build.LazyPath {
    // initialize IO for linker script read
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    defer threaded.deinit();

    // read the linker scripts into ls1 (velox) and ls2 (jumptable)
    const veloxLinkerScript = try std.Io.Dir.cwd().openFile(io, velox_root.path(b, "linker.ld").getPath(b), .{ .mode = .read_only });
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

/// Creates and wires up the three core Velox modules (`velox_core`,
/// `velox_umm`, `velox_sdk`) plus the jumptable dependency.
///
/// All modules target ARM Cortex-A9, freestanding, EABI hard-float.
/// The SDK and core modules receive the jumptable import; the core
/// module also receives the SDK, umm, and build manifest imports.
fn getVeloxModules(b: *std.Build, optimize: std.builtin.OptimizeMode, velox_root: std.Build.LazyPath) VeloxModules {
    const target = getV5Target(b);

    const velox = b.addModule("velox_core", .{ .root_source_file = velox_root.path(b, "src/kernel/boot.zig"), .target = target, .optimize = optimize });
    const umm = b.createModule(.{ .root_source_file = velox_root.path(b, "src/umm/lib.zig"), .target = target, .optimize = optimize });
    const sdk = b.addModule("velox_sdk", .{ .root_source_file = velox_root.path(b, "src/sdk/root.zig"), .target = target, .optimize = optimize });
    const jumptable = b.dependency("velox_jumptable", .{});

    velox.addImport("velox_sdk", sdk);
    velox.addImport("velox_umm", umm);
    velox.addImport("velox_jumptable", jumptable.module("velox_jumptable"));
    const manifest = b.createModule(.{
        .root_source_file = velox_root.path(b, "build.zig.zon"),
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

/// Creates a Velox firmware executable from the given user code.
///
/// The user code module is imported as `user_code` into the kernel.
/// The user module itself receives `velox` (the SDK) as its import.
///
/// ## Arguments
///
/// - `code_root` — path to the user's main `.zig` file.
/// - `optimize` — optimization mode (Debug, ReleaseFast, etc.).
/// - `velox_root` — path to the Velox repository root.
/// - `user_imports` — additional module imports to expose to user code.
///
/// Returns the compiled executable step, ready for installation.
pub fn addExecutable(
    b: *std.Build,
    code_root: std.Build.LazyPath,
    optimize: std.builtin.OptimizeMode,
    velox_root: std.Build.LazyPath,
    user_imports: []const std.Build.Module.Import,
) !*std.Build.Step.Compile {
    const veloxModules = getVeloxModules(b, optimize, velox_root);
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
    for (user_imports) |imp| {
        imp.module.addImport("velox", velox);
        user_code.addImport(imp.name, imp.module);
    }

    const exe = b.addExecutable(.{
        .root_module = velox,
        .name = "velox",
        .use_llvm = true,
    });
    exe.entry = .{ .symbol_name = "__velox_boot__" };

    const ls = try generateLinkerScript(b, velox_root, jumptable);
    exe.setLinkerScript(ls);

    b.installArtifact(exe);

    return exe;
}

/// Errors that can occur during build configuration.
pub const VeloxBuildError = error{
    /// The specified upload slot number does not exist (valid: 1–8).
    NonexistantSlot,
};

/// The available VEX V5 program icons, used when uploading firmware
/// via `cargo-v5`.
///
/// Each variant maps to a string identifier recognized by the VEXos
/// firmware.
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

    /// Returns the string identifier for this icon, as used by
    /// `cargo-v5 --icon`.
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

/// Creates a `cargo-v5 v5 upload` step that uploads the compiled
/// firmware to the V5 Brain.
///
/// ## Arguments
///
/// - `exe` — the compiled executable to upload.
/// - `name` — the program name displayed on the V5 Brain.
/// - `description` — a short description of the program.
/// - `icon` — the [`Icon`] to display on the V5 Brain.
/// - `slot` — the upload slot (1–8).
///
/// ## Errors
///
/// Returns `error.NonexistantSlot` if `slot` is not in 1–8.
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

/// Returns the resolved target triple for the VEX V5 Brain:
/// ARM Cortex-A9, freestanding, EABI hard-float.
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

/// Creates a test executable that runs the on-hardware test suite.
///
/// Uses the `runner/runner.zig` as user code and `runner/shim.zig` as
/// the test runner shim. The test executable is uploaded to the V5 Brain
/// via `cargo-v5`.
fn createTests(b: *std.Build, optimize: std.builtin.OptimizeMode, velox_root: std.Build.LazyPath) !*std.Build.Step.Compile {
    const veloxModules = getVeloxModules(b, optimize, velox_root);
    const velox = veloxModules.core;

    const runnerModule = b.createModule(.{
        .root_source_file = velox_root.path(b, "runner/runner.zig"),
        .optimize = optimize,
        .target = getV5Target(b),
    });
    runnerModule.addImport("velox", veloxModules.sdk);

    velox.addImport("user_code", runnerModule);

    const testing = b.addTest(.{
        .root_module = velox,
        .test_runner = .{
            .path = velox_root.path(b, "runner/shim.zig"),
            .mode = .simple,
        },
    });

    testing.entry = .{ .symbol_name = "__velox_boot__" };

    const ls = try generateLinkerScript(b, velox_root, veloxModules.jumptable);
    testing.setLinkerScript(ls);

    return testing;
}

/// Default build entry point.
///
/// Configures three build steps:
/// - **default** — compiles `mock/user_code.zig` as a firmware image.
/// - **upload** — builds and uploads to slot 8 with the `.matlab` icon.
/// - **test** — builds the test runner and uploads to slot 8.
pub fn build(b: *std.Build) !void {
    const optimize = std.Build.standardOptimizeOption(b, .{});

    const velox_root = b.path(".");

    const exe = try addExecutable(b, b.path("mock/user_code.zig"), optimize, velox_root, &.{});
    b.default_step.dependOn(&exe.step);

    const upload = b.step("upload", "Upload the kernel to the brain");
    const cmd = try addUpload(b, exe, "Velox", "Velox Kernel", .matlab, 8);
    upload.dependOn(b.default_step);
    upload.dependOn(&cmd.step);

    const docgen = b.step("docs", "Create a docs site");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docgen.dependOn(&install_docs.step);

    const testgen = b.step("test", "Build a test runner and upload it to the brain");
    const testing = try createTests(b, optimize, velox_root);
    const uploadTest = try addUpload(b, testing, "Velox Tests", "Tests for the Velox Runtime", .code_file, 8);
    testgen.dependOn(&testing.step);
    testgen.dependOn(&uploadTest.step);
}
