const jmptbl = @import("velox_jumptable");
const units = @import("../units.zig");
const errors = @import("../error.zig");
const convert = @import("../convert.zig");
const pool = @import("../devices.zig");

/// A VEX V5 Rotation Sensor — an absolute encoder that provides
/// precise angular position, velocity, and angle readings.
///
/// Unlike the motor's built-in encoder, the Rotation Sensor is a
/// standalone device with higher resolution and the ability to report
/// absolute angle (0–360°) independent of the number of rotations.
///
/// ## Example
///
/// ```zig
/// var rot = velox_sdk.Rotation.init(3);
/// rot.reset();
///
/// const position = rot.pos();         // cumulative ticks
/// const degrees = rot.angle(.degree); // 0–360
/// const rpm = rot.velocity();
/// ```
pub const Rotation = struct {
    handle: ?*anyopaque,

    /// Initializes a Rotation Sensor on the given port.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var rot = velox_sdk.Rotation.init(3);
    /// ```
    pub fn init(
        /// The smart port number (1–21).
        port: u32,
    ) errors.DeviceInitError!Rotation {
        if (!errors.portIsValid(port))
            return errors.DeviceInitError.InvalidPort;
        const poolIdx: usize = @intCast(port);
        pool.claim(poolIdx) catch {
            return errors.DeviceInitError.PortUsed;
        };
        return Rotation{
            .handle = jmptbl.devices.vexDeviceGetByIndex(port - 1),
        };
    }

    /// Resets the sensor's position to zero.
    ///
    /// This clears the cumulative position counter without affecting
    /// the absolute angle.
    ///
    /// ```zig
    /// rot.reset();
    /// ```
    pub fn reset(self: *const Rotation) void {
        jmptbl.rotation.vexDeviceAbsEncReset(self.handle);
    }

    /// Returns the sensor's velocity in RPM.
    ///
    /// Positive values indicate clockwise rotation; negative values
    /// indicate counter-clockwise.
    ///
    /// ```zig
    /// const rpm = rot.velocity();
    /// ```
    pub fn velocity(self: *const Rotation) i32 {
        // TODO add units
        return jmptbl.rotation.vexDeviceAbsEncVelocityGet(self.handle);
    }

    /// Returns `true` if the sensor's direction is reversed.
    ///
    /// When reversed, the sign of position and velocity readings is
    /// flipped.
    ///
    /// ```zig
    /// if (rot.isReversed()) {
    ///     // readings are inverted
    /// }
    /// ```
    pub fn isReversed(self: *const Rotation) bool {
        return jmptbl.rotation.vexDeviceAbsEncReverseFlagGet(self.handle);
    }

    /// Sets whether the sensor's direction is reversed.
    ///
    /// When reversed, the sign of position and velocity readings is
    /// flipped. This does not affect the physical sensor — only how
    /// readings are reported.
    ///
    /// ```zig
    /// rot.setReversed(true);
    /// ```
    pub fn setReversed(self: *const Rotation, reversed: bool) void {
        jmptbl.rotation.vexDeviceAbsEncReverseFlagSet(self.handle, reversed);
    }

    /// Returns the sensor's cumulative position in encoder ticks.
    ///
    /// This value increases or decreases as the sensor rotates. The
    /// sign depends on the direction of rotation (and whether the
    /// sensor is reversed via [`setReversed`]).
    ///
    /// ```zig
    /// const ticks = rot.pos();
    /// ```
    pub fn pos(self: *const Rotation, unit: units.RotationalUnit) i32 {
        // TODO add units
        return convert.angleFromDegrees(@floatFromInt(jmptbl.rotation.vexDeviceAbsEncPositionGet(self._handle) / 100), unit);
    }

    /// Sets the sensor's position to the given value.
    ///
    /// This redefines the current position without physically moving
    /// the sensor. Useful for establishing a reference point.
    ///
    /// ```zig
    /// rot.setPos(0);  // reset position counter
    /// ```
    pub fn setPos(self: *const Rotation, value: i32) void {
        jmptbl.rotation.vexDeviceAbsEncPositionSet(self.handle, value);
    }

    /// Returns the sensor's absolute angle in the specified units.
    ///
    /// The absolute angle is always in the range 0–360° regardless of
    /// how many full rotations have occurred.
    ///
    /// ## Units
    ///
    /// - `.degree` — degrees (0–360).
    /// - `.turn` — turns / revolutions (0–1).
    /// - `.radian` — radians (0–2π).
    ///
    /// ```zig
    /// const deg = rot.angle(.degree);   // 0–360
    /// const turn = rot.angle(.turn);    // 0.0–1.0
    /// const rad = rot.angle(.radian);   // 0.0–6.28...
    /// ```
    pub fn angle(self: *const Rotation, unit: units.RotationalUnit) f64 {
        const deg = jmptbl.rotation.vexDeviceAbsEncAngleGet(self.handle);
        return convert.angleFromDegrees(deg, unit);
    }

    /// Sets the sensor's data rate in milliseconds.
    ///
    /// The data rate controls how frequently the sensor updates its
    /// readings. Lower values provide more frequent updates but may
    /// increase CPU overhead.
    ///
    /// ```zig
    /// rot.setDataRate(10);  // update every 10 ms
    /// ```
    pub fn setDataRate(self: *const Rotation, rate: u32) void {
        return jmptbl.rotation.vexDeviceAbsEncDataRateSet(self.handle, rate);
    }
};
