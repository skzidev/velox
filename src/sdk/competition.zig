//! VEX competition-mode runtime (§17): autonomous / driver-control /
//! disabled states, read from the competition control line, plus a
//! supervisor task that dispatches user callbacks on transitions.

const std = @import("std");

const jmptbl = @import("velox_jumptable");

/// Raw status word bits (§17.1; bit layout per PROS, hardware-pinned
/// before release).
const flag_autonomous = 0x1;
const flag_disabled = 0x2;
const flag_connected = 0x4;
const flag_enabled = 0x8;

/// The brain's competition state.
pub const State = enum(u8) {
    disconnected,
    disabled,
    autonomous,
    driver_control,
};

/// Namespace-style competition module (`Competition.state()`).
pub const Competition = struct {
    /// The current competition state.
    pub fn state() State {
        const raw = jmptbl.competition.vexCompetitionStatus();
        if ((raw & flag_connected) == 0) return .disconnected;
        if ((raw & flag_disabled) != 0) return .disabled;
        if ((raw & flag_autonomous) != 0) return .autonomous;
        return .driver_control;
    }

    /// True in autonomous or driver control (§17.2).
    pub fn isEnabled() bool {
        return switch (state()) {
            .autonomous, .driver_control => true,
            else => false,
        };
    }

    /// User callbacks for the competition lifecycle (§17.3).
    pub const Callbacks = struct {
        autonomous: ?*const fn () void = null,
        driverControl: ?*const fn () void = null,
    };

    /// Spawn a supervisor task (via `io`) that polls the competition
    /// state every 10 ms and fires the matching callback on each
    /// transition, including the initially observed state.
    ///
    /// The returned future is intentionally never awaited: the task runs
    /// for the life of the program. The one task slot used is held
    /// forever. `error.ConcurrencyUnavailable` propagates unchanged.
    pub fn compete(io: std.Io, callbacks: Callbacks) error{ConcurrencyUnavailable}!void {
        const future = try io.concurrent(runCompetition, .{callbacks});
        _ = future;
    }
};

fn runCompetition(callbacks: Competition.Callbacks) void {
    var prev: ?State = null;
    while (true) {
        const st = Competition.state();
        if (prev == null or st != prev.?) {
            prev = st;
            switch (st) {
                .autonomous => if (callbacks.autonomous) |cb| cb(),
                .driver_control => if (callbacks.driverControl) |cb| cb(),
                else => {},
            }
        }
        jmptbl.task.vexTaskSleep(10);
    }
}
