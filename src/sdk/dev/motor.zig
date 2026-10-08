const jmptbl = @import("velox_jumptable");
const unit = @import("../units.zig");
const port = @import("../ports.zig");
const dev = @import("../internal/dev.zig");

pub const Motor = struct {
    port: port.SmartPort,

    pub const Gearing = enum(jmptbl.types.V5MotorGearset) {
        red,
        green,
        blue,
        _,
    };

    pub const BrakeMode = enum(jmptbl.types.V5MotorBrakeMode) {
        coast,
        brake,
        hold,
        _,
    };

    pub fn init(p: port.SmartPort) Motor {
        return .{
            .port = p,
        };
    }

    pub fn spin(self: *const Motor, units: unit.Power) void {
        const smartDevice = dev.smartDevice(self.port.index);
        jmptbl.motor.vexDeviceMotorVoltageSet(smartDevice, units.toVolt());
    }

    pub fn temp(self: *const Motor) unit.Temperature {
        const sd = dev.smartDevice(self.port.index);
        jmptbl.motor.vexDeviceMotorTemperatureGet(sd);
    }

    pub fn stop(self: *const Motor) void {
        const sd = dev.smartDevice(self.port.index);
        jmptbl.motor.vexDeviceMotorVoltageSet(sd, 0);
    }
};
