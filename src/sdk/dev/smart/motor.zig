const jmptbl = @import("velox_jumptable");
const pu = @import("../../units/power.zig");
const handles = @import("../../internal/handles.zig").handles;

pub const Motor = struct {
    port: usize,

    pub fn direction(self: *const Motor) Direction {
        return @enumFromInt(jmptbl.Motor.vexDeviceMotorReverseFlagGet(handles[self.port - 1]));
    }

    pub fn spin(
        self: *const Motor,
        value: pu.PowerUnit,
    ) void {
        _ = self;
        _ = value;
    }

    pub const Cartridge = enum(c_int) {
        red = 0,
        green,
        blue,
        _,
    };

    pub const Kind = enum(c_int) {
        full = 0,
        half,
        _,
    };

    pub const BrakeMode = enum(c_int) {
        coast = 0,
        brake,
        hold,
        _,
    };

    pub const Direction = enum(u1) {
        forward = 0,
        reverse,
    };
};
