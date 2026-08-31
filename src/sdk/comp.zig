//! # Competition interface

const jmptbl = @import("velox_jumptable");

// TODO design and implement competition interface

pub const Competition = struct {
    pub const CompetitionState = enum(c_int) {
        Disconnected = 0b000,
        DriverControl = 0b001,
        Autonomous = 0b011,
        Disabled = 0b101,
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
};
