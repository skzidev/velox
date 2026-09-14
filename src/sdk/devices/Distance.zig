const jmptbl = @import("velox_jumptable");
const units = @import("../units.zig");
const errors = @import("../error.zig");
const convert = @import("../convert.zig");
const pool = @import("../devices.zig");

/// A VEX V5 Distance Sensor (276-4852).
///
/// Uses infrared to measure the distance to the nearest detected object.
/// Can also report confidence, object size, and object velocity.
///
/// ## Example
///
/// ```zig
/// var dist = try velox_sdk.Distance.init(5);
///
/// const mm: f32 = dist.distance(.millimeter);
/// const cm: f32 = dist.distance(.centimeter);
/// const inches: f32 = dist.distance(.inch);
///
/// if (dist.confidence() > 90) {
///     // high-confidence reading
/// }
/// ```
pub const Distance = struct {
    handle: ?*anyopaque,

    /// Initializes a Distance Sensor on the given port.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var dist = try velox_sdk.Distance.init(5);
    /// ```
    pub fn init(
        /// The smart port number (1–20).
        port: u32,
    ) errors.DeviceInitError!Distance {
        if (!errors.portIsValid(port))
            return errors.DeviceInitError.InvalidPort;
        const poolIdx: usize = @intCast(port);
        pool.claim(poolIdx) catch {
            return errors.DeviceInitError.PortUsed;
        };
        return Distance{
            .handle = jmptbl.devices.vexDeviceGetByIndex(port - 1),
        };
    }

    /// Returns the distance to the nearest detected object in the
    /// specified units.
    ///
    /// The sensor returns `0` when no object is detected within range.
    /// The native output is in millimeters; other units are derived via
    /// conversion.
    ///
    /// ## Units
    ///
    /// | Variant | Conversion |
    /// |---|---|
    /// | `.millimeter` | Native output (no conversion) |
    /// | `.centimeter` | mm / 10 |
    /// | `.inch` | mm / 25.4 |
    /// | `.feet` | mm / 25.4 / 12 |
    ///
    /// ## Example
    ///
    /// ```zig
    /// const distance_mm = dist.distance(.millimeter);
    /// const distance_cm = dist.distance(.centimeter);
    /// ```
    pub fn distance(
        self: *const Distance,
        /// The unit for the returned distance.
        unit: units.LengthUnit,
    ) f32 {
        const mm = jmptbl.distance.vexDeviceDistanceDistanceGet(self.handle);
        return convert.distanceFromMillimeters(@floatFromInt(mm), unit);
    }

    /// Returns the sensor's confidence in the current distance reading
    /// (0–100).
    ///
    /// A higher value indicates greater certainty. Values below ~50
    /// suggest the reading may be unreliable (e.g. object at edge of
    /// range, or no object detected).
    ///
    /// ```zig
    /// const conf = dist.confidence();
    /// if (conf > 80) {
    ///     // reliable reading
    /// }
    /// ```
    pub fn confidence(
        self: *const Distance,
    ) u32 {
        return jmptbl.distance.vexDeviceDistanceConfidenceGet(self.handle);
    }

    /// Returns the detected object's size as reported by the sensor.
    ///
    /// The raw value is on an internal 400-unit scale and does not
    /// directly correspond to a physical dimension. Use this as a
    /// relative indicator (larger values = larger objects).
    ///
    /// ```zig
    /// const size = dist.objectSize();
    /// ```
    pub fn objectSize(
        self: *const Distance,
    ) i32 {
        return jmptbl.distance.vexDeviceDistanceObjectSizeGet(self.handle);
    }

    /// Returns the detected object's velocity in meters per second.
    ///
    /// Positive values indicate the object is moving away; negative
    /// values indicate it is approaching. Returns `0` when no object
    /// is detected or velocity cannot be determined.
    ///
    /// ```zig
    /// const vel = dist.objectVelocity();
    /// if (vel < -0.5) {
    ///     // object approaching quickly
    /// }
    /// ```
    pub fn objectVelocity(
        self: *const Distance,
    ) f64 {
        return jmptbl.distance.vexDeviceDistanceObjectVelocityGet(self.handle);
    }
};
