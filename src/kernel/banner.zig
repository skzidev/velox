const builtin = @import("builtin");
const std = @import("std");
const manifest = @import("manifest");

fn optimizationModeToString(comptime O: std.lang.Optimize) []const u8 {
    return switch (O) {
        .debug => "Debug",
        .fast => "ReleaseFast",
        .small => "ReleaseSmall",
        .safe => "ReleaseSafe",
    };
}

/// Program banner
pub const banner = std.fmt.comptimePrint(
    \\
    \\                            /|        | Velox v{s}
    \\  ______        ___________/_/        | Zig v{s}
    \\ \\    \\      |     //     //        | Compilation target: {s}
    \\   \\    \\    |___//     //          | Runtime safety: {s}
    \\     \\    \\    //     //            | Build Mode: {s}
    \\       \\    \\//     //_____         | Debug symbols: {s}
    \\         \\         //       |        |
    \\          \\_______//________|        |
    \\                / /                   |
    \\                |/                    | Copyright (c) 2026 59218C, licensed under MIT.
    \\
, .{
    "0.1.0-alpha",
    builtin.zig_version_string,
    builtin.cpu.model.name,
    if (builtin.optimize.runtimeSafety()) "enabled" else "disabled",
    builtin.optimize,
    if (builtin.strip_debug_info) "excluded" else "included",
});
