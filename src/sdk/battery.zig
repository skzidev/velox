const conversions = @import("./convert.zig");
const units = @import("./units.zig");
const jmptbl = @import("velox_jumptable");

/// Interface for reading the V5 Brain's battery level.
///renamed
/// The V5 Brain's built-in battery provides power to the brain and all
/// connected devices. This module provides access to battery telemetry.
///
pub const Battery = struct {
    pub fn level() f64 {
        return jmptbl.battery.vexBatteryCapacityGet();
    }

    pub fn voltage() i32 {
        return jmptbl.battery.vexBatteryVoltageGet();
    }

    pub fn current() i32 {
        return jmptbl.battery.vexBatteryCurrentGet();
    }

    pub fn temp(unit: units.TempUnit) f64 {
        return conversions.tempToUnit(jmptbl.battery.vexBatteryTemperatureGet(), unit);
    }
};
