/// Units for motor rotational speed.
///
/// Used with [`Motor.spinAt`](root.Motor.spinAt) to specify the speed
/// unit for motor control.
///
/// | Variant | Meaning |
/// |---|---|
/// | `.rpm` | Revolutions per minute |
/// | `.mvolts` | Voltage in millivolts (V5 range: -12000 to 12000) |
/// | `.volts` | Voltage in volts (V5 range: -12.0 to 12.0) |
/// | `.percent` | Percentage of max speed (-100 to 100) |
pub const MotorUnit = enum {
    /// Revolutions per minute. The motor will attempt to hold this speed
    /// using its internal PID controller.
    rpm,
    /// Percentage of maximum speed. Range: -100 to 100. Internally
    /// converted to millivolts before being sent to the hardware.
    percent,
} || VoltageUnit;

/// Units for temperature readings.
///
/// Used with [`Motor.temp`](root.Motor.temp) to specify the output unit.
///
/// | Variant | Meaning |
/// |---|---|
/// | `.celsius` | Degrees Celsius |
/// | `.fahrenheit` | Degrees Fahrenheit |
pub const TempUnit = enum {
    /// Degrees Celsius.
    celsius,
    /// Degrees Fahrenheit.
    fahrenheit,
};

/// Units of length or distance.
///
/// Used with [`Distance.distance`](root.Distance.distance) to specify the
/// output unit for distance measurements.
///
/// | Variant | Meaning |
/// |---|---|
/// | `.millimeter` | Millimeters (mm) |
/// | `.centimeter` | Centimeters (cm) |
/// | `.inch` | Inches (in) |
/// | `.feet` | Feet (ft) |
pub const LengthUnit = enum {
    /// Inches.
    inch,
    /// Feet.
    foot,
    /// Millimeters.
    millimeter,
    /// Centimeters.
    centimeter,
};

/// Units for rotational position and angle readings.
///
/// Used with [`Motor.pos`](root.Motor.pos), [`Motor.setPos`](root.Motor.setPos),
/// [`Rotation.angle`](root.Rotation.angle), and
/// [`Inertial.heading`](root.Inertial.heading) to specify the output unit.
///
/// | Variant | Meaning |
/// |---|---|
/// | `.degree` | Degrees (0–360) |
/// | `.turn` | Turns / revolutions (0–1) |
/// | `.radian` | Radians (0–2π) |
pub const RotationalUnit = enum {
    /// Degrees. One full rotation = 360 degrees.
    degree,
    /// Turns (revolutions). One full rotation = 1 turn.
    turn,
    /// Radians. One full rotation = 2π radians.
    radian,
};

pub const VoltageUnit = enum {
    /// Voltage in volts. The V5 motor accepts values from -12.0 to 12.0 V.
    /// Internally converted to millivolts (`volts * 1000`) before being
    /// sent to the hardware.
    volts,
    /// Voltage in millivolts. The V5 motor accepts integer values from
    /// -12000 to 12000 mV.
    mvolts,
};
