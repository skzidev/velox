//! # Competition interface
//!
//! Manages the VEX Competition state machine: autonomous, driver control,
//! and disabled phases. Spawns the appropriate callback as a concurrent
//! task and cancels it on phase transitions.
//!
//! ## Example
//!
//! ```zig
//! fn autonomous() void { /* auto code */ }
//! fn driverControl() void { /* driver code */ }
//!
//! pub fn main(init: velox_sdk.Init) !void {
//!     try velox_sdk.Competition.compete(init.io, .{
//!         .autonomous = &autonomous,
//!         .driverControl = &driverControl,
//!     });
//! }
//! ```

const jmptbl = @import("velox_jumptable");
const std = @import("std");
const errors = @import("error.zig");

/// Errors the supervisor itself can produce: spawning a callback task may
/// hit a concurrency limit, and `io.sleep` is a cancelation point.
const SupervisorError = std.Io.ConcurrentError || std.Io.Cancelable;

/// Comptime-known trampolines that let the runtime `*const fn () void`
/// callbacks be spawned through `std.Io.concurrent`, which requires a
/// function type rather than a function pointer. The `Callbacks` are
/// carried as the concurrent task's context.
fn spawnAutonomous(callbacks: Competition.Callbacks) void {
    callbacks.autonomous();
}

fn spawnDriverControl(callbacks: Competition.Callbacks) void {
    callbacks.driverControl();
}

/// Background supervisor task that polls the competition state and
/// manages transitions between autonomous, driver control, and disabled
/// phases.
///
/// Runs indefinitely, sleeping 2 ms between polls. On each iteration:
/// - If the state transitions to **Autonomous**, the current task is
///   cancelled and the `autonomous` callback is spawned concurrently.
/// - If the state transitions to **Driver Control**, the current task is
///   cancelled and the `driverControl` callback is spawned concurrently.
/// - If the state is **Disabled**, the running task is cancelled.
fn supervisor(io: std.Io, callbacks: Competition.Callbacks) SupervisorError!void {
    var running: ?std.Io.Future(void) = null;
    var prev_state = Competition.State.disconnected;
    while (true) {
        const current = Competition.state();
        if (current != prev_state) {
            if (running) |*r| r.cancel(io);
            running = switch (current) {
                .autonomous => try io.concurrent(spawnAutonomous, .{callbacks}),
                .driver_control => try io.concurrent(spawnDriverControl, .{callbacks}),
                .disabled, .disconnected => null,
            };
            prev_state = current;
        }
        try io.sleep(.fromMilliseconds(2), .awake);
    }
}

/// The VEX Competition state machine interface.
///
/// Use [`compete`] to start the supervisor that manages match phases.
/// Use [`state`] to read the current competition status directly.
pub const Competition = struct {
    /// The current state of the competition match.
    ///
    /// The underlying values are bitmask constants from the VEXos
    /// `vexCompetitionStatus` API.
    ///
    /// | Variant | Bitmask | Meaning |
    /// |---|---|---|
    /// | `.disconnected` | `0b000` | No field control connected |
    /// | `.driver_control` | `0b001` | Driver control period active |
    /// | `.autonomous` | `0b011` | Autonomous period active |
    /// | `.disabled` | `0b101` | Match disabled |
    pub const State = enum(u8) {
        disconnected = 0b000,
        driver_control = 0b001,
        autonomous = 0b011,
        disabled = 0b101,
    };

    /// Callbacks for match phase transitions.
    ///
    /// Each field is a function pointer invoked as a concurrent task
    /// when the corresponding phase begins.
    pub const Callbacks = struct {
        autonomous: *const fn () void,
        driverControl: *const fn () void,
    };

    /// Reads the current competition state from the VEXos firmware.
    ///
    /// Returns the [`State`] that matches the current field control
    /// status.
    ///
    /// ```zig
    /// const state = velox_sdk.Competition.state();
    /// ```
    pub fn state() State {
        const status = jmptbl.competition.vexCompetitionStatus();
        if (status & @intFromEnum(State.autonomous) != 0) {
            return .autonomous;
        } else if (status & @intFromEnum(State.driver_control) != 0) {
            return .driver_control;
        } else if (status & @intFromEnum(State.disabled) != 0) {
            return .disabled;
        } else {
            return .disconnected;
        }
    }

    /// Returns `true` if the current state is autonomous.
    pub fn isAutonomous() bool {
        return state() == .autonomous;
    }

    /// Returns `true` if the current state is driver control.
    pub fn isDriverControl() bool {
        return state() == .driver_control;
    }

    /// Returns `true` if the match is disabled.
    pub fn isDisabled() bool {
        return state() == .disabled;
    }

    /// Returns `true` if the robot is enabled (autonomous or driver
    /// control).
    pub fn isEnabled() bool {
        const s = state();
        return s == .autonomous or s == .driver_control;
    }

    /// Returns `true` if a competition switch or field control system
    /// is connected (i.e. not running standalone).
    pub fn isCompetitionSwitchConnected() bool {
        return jmptbl.competition.vexCompetitionStatus() != 0;
    }

    pub const CompetitionError = (errors.MotionError || std.Io.ConcurrentError);

    /// # velox.Competition.compete()
    ///
    /// Starts the competition supervisor as a concurrent background task.
    ///
    /// The supervisor polls the competition state every 2 ms and
    /// spawns/cancels the appropriate callback. This function returns
    /// immediately — the supervisor runs in the background.
    ///
    /// Returns `error.ConcurrencyUnavailable` if the concurrency system
    /// cannot allocate a task slot for the supervisor.
    ///
    /// ## Example
    ///
    /// ```zig
    /// try velox_sdk.Competition.compete(app.io, .{
    ///     .autonomous = &autonomous,
    ///     .driverControl = &driverControl,
    /// });
    /// ```
    ///
    pub fn compete(
        /// V5Io instance
        io: std.Io,
        /// Competition callbacks
        callbacks: Callbacks,
    ) CompetitionError!std.Io.Future(SupervisorError!void) {
        return try io.concurrent(supervisor, .{ io, callbacks });
    }
};
