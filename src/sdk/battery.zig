const conversions = @import("convert.zig");
const units = @import("units.zig");
const jmptbl = @import("velox_jumptable");

/// Interface for reading the V5 Brain's battery level.
///
/// The V5 Brain's built-in battery provides power to the brain and all
/// connected devices. This module provides access to battery telemetry.
///
/// ## Example
///
/// ```zig
/// velox_sdk.Battery.getLevel();
/// ```
pub const Battery = struct {
    pub fn level() f64 {
        return jmptbl.battery.vexBatteryCapacityGet();
    }

    // pub fn current() i32 {
    //     return jmptbl.battery.vexBatteryCurrentGet();
    // }

    pub fn temp(unit: units.TempUnit) f64 {
        return conversions.tempToUnit(jmptbl.battery.vexBatteryTemperatureGet(), unit);
    }

    pub fn voltage(unit: units.VoltageUnit) f32 {
        return conversions.voltageFromVolts(jmptbl.battery.vexBatteryVoltageGet(), unit);
    }
};
