const jmptbl = @import("velox_jumptable");
const pu = @import("../../units/power.zig");
const au = @import("../../units/angle.zig");
const handleMod = @import("../../internal/handles.zig");
const port = @import("../port.zig");

pub const Motor = struct {
    port: port.SmartPort,

    pub fn direction(self: *const Motor) Direction {
        return @enumFromInt(jmptbl.motor.vexDeviceMotorReverseFlagGet(handleMod.handles[self.port.idx]));
    }

    pub fn stop(self: *const Motor) void {
        jmptbl.motor.vexDeviceMotorVelocitySet(handleMod.handles[self.port.idx], 0);
    }

    pub fn position(self: *const Motor) au.AngleUnits {
        return .fromDegree(jmptbl.motor.vexDeviceMotorPositionGet(handleMod.handles[self.port.idx]));
    }

    pub fn spin(
        self: *const Motor,
        value: pu.PowerUnit,
    ) void {
        jmptbl.motor.vexDeviceMotorVoltageSet(handleMod.handles[self.port.idx], value.volts);
    }

    pub fn init(motorPort: port.SmartPort, dir: Direction, cart: Cartridge, bm: BrakeMode) Motor {
        // TODO check if device is of valid type
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
