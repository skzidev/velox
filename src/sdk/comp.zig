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
//!     velox_sdk.Competition.compete(init.io, .{
//!         .autonomous = &autonomous,
//!         .driverControl = &driverControl,
//!     });
//! }
//! ```

const jmptbl = @import("velox_jumptable");
const std = @import("std");

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
fn supervisor(io: std.Io, callbacks: Competition.MatchStateCallbacks) !void {
    var runningFunctionState = Competition.CompetitionState.Disabled;
    var runningFunction: std.Io.Future(void) = null;
    while (true) {
        if (Competition.state() == Competition.CompetitionState.Autonomous and runningFunctionState != Competition.CompetitionState.Autonomous) {
            runningFunction.cancel();
            runningFunctionState = Competition.CompetitionState.Autonomous;
            runningFunction = try io.concurrent(callbacks.autonomous, .{});
            // TODO don't use try here
        } else if (Competition.state() == Competition.CompetitionState.DriverControl and runningFunctionState != Competition.CompetitionState.DriverControl) {
            runningFunction.cancel();
            runningFunctionState = Competition.CompetitionState.DriverControl;
            runningFunction = try io.concurrent(callbacks.driverControl, .{});
            // TODO don't use try here
        } else if (Competition.state() == Competition.CompetitionState.Disabled) {
            runningFunction.cancel();
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
    /// | `.Disconnected` | `0b000` | No field control connected |
    /// | `.DriverControl` | `0b001` | Driver control period active |
    /// | `.Autonomous` | `0b011` | Autonomous period active |
    /// | `.Disabled` | `0b101` | Match disabled |
    pub const CompetitionState = enum(c_int) {
        /// No field control system is connected.
        Disconnected = 0b000,
        /// Driver control period is active.
        DriverControl = 0b001,
        /// Autonomous period is active.
        Autonomous = 0b011,
        /// Match is disabled.
        Disabled = 0b101,
    };

    /// Callbacks for match phase transitions.
    ///
    /// Each field is a function pointer invoked as a concurrent task
    /// when the corresponding phase begins.
    pub const MatchStateCallbacks = struct {
        /// Called when the driver control period begins.
        driverControl: *const fn () void,
        /// Called when the autonomous period begins.
        autonomous: *const fn () void,
    };

    /// Reads the current competition state from the VEXos firmware.
    ///
    /// Returns the [`CompetitionState`] that matches the current field
    /// control status.
    ///
    /// ```zig
    /// const state = velox_sdk.Competition.state();
    /// ```
    pub fn state() CompetitionState {
        const status = jmptbl.competition.vexCompetitionStatus();
        if (status & CompetitionState.Autonomous) {
            return CompetitionState.Autonomous;
        } else if (status & CompetitionState.DriverControl) {
            return CompetitionState.DriverControl;
        } else if (status & CompetitionState.Disabled) {
            return CompetitionState.Disabled;
        } else {
            return CompetitionState.Disconnected;
        }
    }

    /// Starts the competition supervisor as a concurrent background task.
    ///
    /// The supervisor polls the competition state every 2 ms and
    /// spawns/cancels the appropriate callback. This function returns
    /// immediately — the supervisor runs in the background.
    ///
    /// ## Example
    ///
    /// ```zig
    /// velox_sdk.Competition.compete(app.io, .{
    ///     .autonomous = &autonomous,
    ///     .driverControl = &driverControl,
    /// });
    /// ```
    pub fn compete(io: std.Io, callbacks: MatchStateCallbacks) void {
        _ = io.concurrent(supervisor, .{ io, callbacks });
    }
};
