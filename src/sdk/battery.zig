//! V5 brain battery (§16).

const std = @import("std");
const jmptbl = @import("velox_jumptable");

/// Namespace-style battery module: `battery.voltage()`.
pub const Battery = struct {
    /// Battery voltage, volts.
    pub fn voltage() f64 {
        return @as(f64, @floatFromInt(jmptbl.battery.vexBatteryVoltageGet())) / 1000.0;
    }

    /// Battery current, amps (signed; discharge is reported positive).
    pub fn current() f64 {
        return @as(f64, @floatFromInt(jmptbl.battery.vexBatteryCurrentGet())) / 1000.0;
    }

    /// Battery temperature, degrees Celsius.
    pub fn temperature() f64 {
        return jmptbl.battery.vexBatteryTemperatureGet();
    }

    /// Remaining capacity, percent. The OS reports a raw value this SDK
    /// treats as a percentage and clamps to [0, 100]; the raw scaling is
    /// hardware-pinned in §16.
    pub fn capacity() f64 {
        return std.math.clamp(jmptbl.battery.vexBatteryCapacityGet(), 0.0, 100.0);
    }
};
