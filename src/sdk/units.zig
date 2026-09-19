//! Canonical unit namespaces (spec §4).
//!
//! Every unit union carries one value; the conversion to the canonical
//! dimension is performed exactly once at the driver boundary and never
//! round-trips. "Every power argument is canonical" means the driver
//! reads whatever field you handed it and converts it to the jumptable's
//! native unit before forwarding.

/// Electrical power delivered to a motor or ADI output.
///
/// Canonical dimension: millivolts (mV), clamped to ±12000.
pub const Power = union(enum) {
    /// Plain integer percentage, [-100, 100]. Enforced as an integer
    /// percentage ("±100"). 100 = full motor voltage.
    percent: i32,
    /// Voltage, volts, signed: [-12, 12].
    volt: f64,
    /// Voltage, millivolts, signed.
    mvolt: i32,
};

/// Rotational velocity of a smart device.
///
/// Canonical dimension: rpm, clamped to the free speed of the motor's
/// current gearset (100/200/600 rpm) for motors; rotation sensors report
/// rpm of their own shaft.
pub const Velocity = union(enum) {
    rpm: f64,
    percent: f64,
};

/// Absolute rotation angle or position.
///
/// Canonical dimension: degrees. No clamp is applied to positions.
pub const Position = union(enum) {
    degree: f64,
    turn: f64,
    radian: f64,
};
