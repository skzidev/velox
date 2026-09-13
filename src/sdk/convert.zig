//! # Unit conversion helpers
//!
//! Pure, hardware-free conversion functions used by the Velox SDK device
//! drivers. Because they never touch the VEXos jumptable they can run on
//! any host, which makes them straightforward to unit test.

const units = @import("units.zig");
const std = @import("std");

/// Converts a temperature in Celsius to the requested output unit.
pub fn tempToUnit(celsius: f64, unit: units.TempUnit) f64 {
    return switch (unit) {
        .celsius => celsius,
        .fahrenheit => (celsius * (9.0 / 5.0)) + 32,
    };
}

/// Converts a distance in millimeters to the requested output unit.
pub fn distanceFromMillimeters(mm: f32, unit: units.LengthUnit) f32 {
    return switch (unit) {
        .millimeter => mm,
        .centimeter => mm / 10,
        .inch => mm / 25.4,
        .foot => (mm / 25.4) / 12,
    };
}

pub fn voltageFromVolts(v: f32, unit: units.VoltageUnit) f32 {
    return switch (unit) {
        .volts => v,
        .mvolts => v * 1000,
    };
}

/// Converts a rotational position expressed in degrees to the requested
/// rotational unit.
pub fn angleFromDegrees(degrees: f64, unit: units.RotationalUnit) f64 {
    return switch (unit) {
        .degree => degrees,
        .radian => degrees * (std.math.pi / 180.0),
        .turn => degrees / 360,
    };
}

/// Converts a rotational position expressed in degrees to a value suitable
/// for the motor's absolute target position (always in degrees).
pub fn positionToDegrees(position: f64, unit: units.RotationalUnit) f64 {
    return switch (unit) {
        .degree => position,
        .radian => position * (180.0 / std.math.pi),
        .turn => position * 360,
    };
}

/// Converts a motor speed command into the raw millivolt value expected by
/// the VEXos jumptable.
///
/// ## Units
///
/// - `.rpm` is **not** convertible to a voltage and returns `null`.
/// - `.mvolts` passes the value through unchanged.
/// - `.volts` scales the value by 1000.
/// - `.percent` maps -100..100 onto millivolts using the approximation
///   `(speed * 127) / 100`.
pub fn motorSpeedToMvolts(speed: i32, unit: units.MotorUnit) ?i32 {
    return switch (unit) {
        .rpm => null,
        .mvolts => speed,
        .volts => speed * 1000,
        .percent => @divTrunc((speed * 127), 100),
    };
}
