const jmptbl = @import("velox_jumptable");
const pu = @import("../../units/power.zig");
const handleMod = @import("../../internal/handles.zig");
const port = @import("../port.zig");

pub const Motor = struct {
    port: port.SmartPort,

    pub fn direction(self: *const Motor) Direction {
        return @enumFromInt(jmptbl.Motor.vexDeviceMotorReverseFlagGet(handleMod.handles[self.port.idx]));
    }

    pub fn spin(
        self: *const Motor,
        value: pu.PowerUnit,
    ) void {
        _ = self;
        _ = value;
    }

    pub fn init(motorPort: port.SmartPort, dir: Direction, cart: Cartridge, bm: BrakeMode) Motor {
        const dev = jmptbl.devices.vexDeviceGetByIndex(motorPort.idx);
        jmptbl.motor.vexDeviceMotorReverseFlagSet(dev, @intFromBool(dir == .reverse));
        jmptbl.motor.vexDeviceMotorGearingSet(dev, @enumFromInt(@intFromEnum(cart)));
        jmptbl.motor.vexDeviceMotorBrakeModeSet(dev, @enumFromInt(@intFromEnum(bm)));
        handleMod.handles[motorPort.idx] = dev;
        return .{
            .port = motorPort,
        };
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
