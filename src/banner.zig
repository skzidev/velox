//! # Banner and Version
//! This file contains the version and the banner which is printed on bootup

const std = @import("std");
const jmptbl = @import("velox_jumptable");
const builtin = @import("builtin");
const assert = @import("testing.zig").assert;

pub const VeloxVersionAsString = "0.0.1";
const VeloxVersion: std.SemanticVersion = .{
    .major = 0,
    .minor = 0,
    .patch = 1,
};
// const VeloxVersionAsString = std.fmt.comptimePrint("{d}.{d}.{d}", .{ VeloxVersion.major, VeloxVersion.minor, VeloxVersion.patch });

const banner = std.fmt.comptimePrint(
    \\
    \\                            /|        | Velox v{s}
    \\  ______        ___________/_/        | Zig v{s}
    \\ \\    \\      |     //     //        | Compiled for {s}
    \\   \\    \\    |___//     //          | SIMD support {s}
    \\     \\    \\    //     //            | Built with type {s}
    \\       \\    \\//     //_____         | {s} a test runner
    \\         \\         //       |        |
    \\          \\_______//________|        |
    \\                / /                   |
    \\                |/                    | Copyright (c) 2026 59218C, licensed under MIT.
    \\
, .{ VeloxVersionAsString, builtin.zig_version_string, builtin.target.cpu.model.name, if (builtin.target.cpu.features.isEnabled(@intFromEnum(std.Target.arm.Feature.neon))) "enabled" else "disabled", switch (builtin.mode) {
    .Debug => "Debug",
    .ReleaseFast => "Release (speed)",
    .ReleaseSafe => "Release (safe)",
    .ReleaseSmall => "Release (small)",
}, if (builtin.is_test) "Is" else "Is Not" });

pub fn printBanner() void {
    _ = jmptbl.serial.vexSerialWriteBuffer(1, @constCast(banner), banner.len);
}

pub fn serialFlush() void {
    var prev_free: i32 = -1;
    var stable_samples: u32 = 0;
    while (stable_samples < 2) {
        jmptbl.task.vexTaskSleep(1);
        const free = jmptbl.serial.vexSerialWriteFree(1);
        if (free == prev_free) {
            stable_samples += 1;
        } else {
            stable_samples = 0;
        }
        prev_free = free;
    }
}

test "ensure banner is correct" {
    try assert(std.mem.containsAtLeast(u8, banner, 1, "Is a test runner"));
    try assert(std.mem.containsAtLeast(u8, banner, 1, "Compiled for cortex_a9"));
    try assert(std.mem.containsAtLeast(u8, banner, 1, "Velox v" ++ VeloxVersionAsString));
}
