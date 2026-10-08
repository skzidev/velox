//! Canonical unit namespaces (spec §4).
//!
//! Every unit union carries one value; the conversion to the canonical
//! dimension is performed exactly once at the driver boundary and never
//! round-trips. "Every power argument is canonical" means the driver
//! reads whatever field you handed it and converts it to the jumptable's
//! native unit before forwarding.

const std = @import("std");

/// Electrical power delivered to a motor or ADI output.
///
/// Canonical dimension: millivolts (mV), clamped to ±12000.
pub const Power = struct {
    _v: f64,

    pub fn toVolt(self: *const Power) f64 {
        return self._v;
    }

    pub fn toMillivolt(self: *const Power) f64 {
        return self._v * 1000;
    }

    pub fn toPercent(self: *const Power) f64 {
        return (self._v / 127.0) * 100;
    }

    pub fn fromVolt(volts: f64) Power {
        return Power{
            ._v = volts,
        };
    }

    pub fn fromMillvolt(millivolts: f64) Power {
        return Power{
            ._v = millivolts / 1000.0,
        };
    }

    pub fn fromPercent(percent: f64) Power {
        return Power{
            ._v = (percent / 100) * 127,
        };
    }
};

/// Rotational velocity unit
///
/// Canonical dimension: rpm, clamped to the free speed of the motor's
/// current gearset (100/200/600 rpm) for motors; rotation sensors report
/// rpm of their own shaft.
pub const Velocity = struct {
    _r: i32,

    pub fn toRPM(self: *const Velocity) i32 {
        return self._r;
    }

    pub fn fromRPM(rpm: i32) Velocity {
        return Velocity{
            ._r = rpm,
        };
    }
};

/// Absolute rotation angle or position.
///
/// Canonical dimension: degrees. No clamp is applied to positions.
pub const Position = struct {
    _d: i32,

    pub fn toDegree(self: *const Position) i32 {
        return self._d;
    }

    pub fn fromDegree(degrees: i32) Position {
        return Position{
            ._d = degrees,
        };
    }

    pub fn toRotations(self: *const Position) f64 {
        return self._d / 360.0;
    }

    pub fn fromRotations(rotations: f64) Position {
        return Position{
            ._d = rotations * 360,
        };
    }

    pub fn toRadians(self: *const Position) f64 {
        return self._d * (180 / std.math.pi);
    }

    pub fn fromRadians(radians: f64) Position {
        return Position{
            ._d = radians * (std.math.pi / 180),
        };
    }
};

pub const Temperature = struct {
    _f: f64,

    pub fn fromFahrenheit(degrees: f64) Temperature {
        return Temperature{
            ._f = degrees,
        };
    }

    pub fn toFahrenheit(self: *const Temperature) f64 {
        return self._f;
    }

    pub fn toCelsius(self: *const Temperature) f64 {
        return (self._f - 32) * (5 / 9);
    }

    pub fn fromCelsius(degrees: f64) Temperature {
        return Temperature{
            ._f = (degrees * (9 / 5)) + 32,
        };
    }
};
