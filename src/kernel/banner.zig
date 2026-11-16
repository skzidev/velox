const builtin = @import("builtin");
const std = @import("std");
const manifest = @import("manifest");

/// Program banner
pub const banner = std.fmt.comptimePrint(
    \\
    \\                            /|        | Velox v{s}
    \\  ______        ___________/_/        | Zig v{s}
    \\ \\    \\      |     //     //        | Compiled for {s}
    \\   \\    \\    |___//     //          | Safety checks {s}
    \\     \\    \\    //     //            | Debug symbols {s}
    \\       \\    \\//     //_____         |
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
    if (builtin.strip_debug_info) "excluded" else "included",
});
