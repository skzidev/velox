const builtin = @import("builtin");
const std = @import("std");

fn optimizationModeToString(comptime O: std.builtin.OptimizeMode) []const u8 {
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
    @import("manifest").version,
    builtin.zig_version_string,
    builtin.cpu.model.name,
    if (builtin.mode == .debug or builtin.mode == .safe) "enabled" else "disabled",
    optimizationModeToString(builtin.mode),
    if (builtin.strip_debug_info) "excluded" else "included",
});
