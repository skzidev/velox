//! Unit-conversion helpers. Conversion happens exactly once, at the
//! driver boundary, and is never round-tripped (§4).

const std = @import("std");
const units = @import("../units.zig");

/// The maximum motor voltage, millivolts.
pub const max_mvolts: i32 = 12000;

/// Convert a `Power` to canonical millivolts, clamped to ±12000 (§4).
pub fn powerToMvolts(power: units.Power) i32 {
    return switch (power) {
        .mvolt => |v| std.math.clamp(v, -max_mvolts, max_mvolts),
        .volt => |v| std.math.clamp(@as(i32, @intFromFloat(std.math.round(v * 1000.0))), -max_mvolts, max_mvolts),
        .percent => |p| std.math.clamp(@as(i32, @intFromFloat(std.math.round(@as(f64, @floatFromInt(std.math.clamp(p, -100, 100))) * 120.0))), -max_mvolts, max_mvolts),
    };
}

/// Convert a `Power` to a velocity-unit free-speed percentage, clamped
/// to ±100. Used when commanding motor velocity from a power.
pub fn powerToPercent(power: units.Power) f64 {
    const mv: f64 = @floatFromInt(powerToMvolts(power));
    return std.math.clamp(mv / 120.0, -100.0, 100.0);
}

/// Convert a `Power` to ADI output duty, ±100 (power is ±12 V there).
pub fn powerToAdiPercent(power: units.Power) f64 {
    return switch (power) {
        .percent => |p| std.math.clamp(@as(f64, @floatFromInt(p)), -100.0, 100.0),
        .volt => |v| std.math.clamp(v / 12.0, -1.0, 1.0) * 100.0,
        .mvolt => |mv| std.math.clamp(@as(f64, @floatFromInt(mv)) / 12000.0, -1.0, 1.0) * 100.0,
    };
}

/// Convert a `Velocity` to canonical rpm, clamped to the motor's current
/// gearset free speed (or a provided limit).
pub fn velocityToRpm(velocity: units.Velocity, max_rpm: f64) i32 {
    const rpm: f64 = switch (velocity) {
        .rpm => |r| r,
        .percent => |p| std.math.clamp(p, -100.0, 100.0) * max_rpm / 100.0,
    };
    return @intFromFloat(std.math.round(std.math.clamp(rpm, -max_rpm, max_rpm)));
}

/// Convert a `Position` to canonical degrees. Positions are never
/// clamped (§4); a turn = 360°, a radian = 180/π°.
pub fn positionToDegrees(position: units.Position) f64 {
    return switch (position) {
        .degree => |d| d,
        .turn => |t| t * 360.0,
        .radian => |r| r * 180.0 / std.math.pi,
    };
}
