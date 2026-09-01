//! # Competition interface

const jmptbl = @import("velox_jumptable");
const std = @import("std");

// TODO design and implement competition interface
//
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

pub const Competition = struct {
    pub const CompetitionState = enum(c_int) {
        Disconnected = 0b000,
        DriverControl = 0b001,
        Autonomous = 0b011,
        Disabled = 0b101,
    };

    pub const MatchStateCallbacks = struct {
        driverControl: *const fn () void,
        autonomous: *const fn () void,
    };

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

    pub fn compete(io: std.Io, callbacks: MatchStateCallbacks) void {
        _ = io.concurrent(supervisor, .{ io, callbacks });
    }
};
