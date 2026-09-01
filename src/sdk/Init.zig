const std = @import("std");

/// The "Juicy Main" — the entry point for all Velox user programs.
///
/// A comptime-generic struct. Pass your device configuration as the
/// type parameter and default-initialize to get a fully wired application
/// context.
///
/// ## Fields
///
/// - `.gpa` — a `DebugAllocator` with thread safety enabled.
/// - `.arena` — an `ArenaAllocator` backed by the GPA.
/// - `.io` — a `std.Io` instance backed by `V5Io`.
/// - `.devices` — a `Peripherals` struct with typed device handles.
///
/// ## Example
///
/// ```zig
/// const velox = @import("velox_sdk");
///
/// const MyDevices = struct {
///     drive_left: struct { .type = .motor },
///     drive_right: struct { .type = .motor },
///     intake_dist: struct { .type = .distance },
/// };
///
/// pub fn main() void {
///     var app = velox.Init(MyDevices){};
///
///     app.devices.drive_left.spinAt(100, .percent);
///     app.devices.drive_right.spinAt(100, .percent);
///
///     var stdout = app.io.stdout();
///     _ = try stdout.writeAll("robot ready\n");
/// }
/// ```
pub const Init = struct {
    /// A `DebugAllocator` with thread safety enabled.
    gpa: std.heap.DebugAllocator(.{ .thread_safe = true }),

    /// An `ArenaAllocator` backed by the GPA.
    arena: std.heap.ArenaAllocator,

    /// The `std.Io` instance for this application.
    io: std.Io,
};
