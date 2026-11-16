const jmptbl = @import("jumptable");

pub fn isDisabled() bool {
    return jmptbl.vexCompetitionStatus() & 0x1;
}

pub fn isAuton() bool {
    return jmptbl.vexCompetitionStatus() & 0x2;
}

pub fn isConnected() bool {
    return jmptbl.vexCompetitionStatus() & 0x4;
}
