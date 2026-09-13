const jmptbl = @import("velox_jumptable");
const units = @import("../units.zig");
const errors = @import("../error.zig");
const convert = @import("../convert.zig");
const pool = @import("../devices.zig");

/// A VEX V5 Inertial Sensor (IMU) — provides orientation, heading,
/// and quaternion data for tracking robot rotation.
///
/// After [`reset`], the sensor calibrates for approximately 2 seconds
/// before providing stable readings.
///
/// ## Example
///
/// ```zig
/// var imu = velox_sdk.Inertial.init(6);
/// imu.reset();  // calibrate (~2 seconds)
///
/// const heading_deg = imu.heading(.degree);
/// const heading_rad = imu.heading(.radian);
/// ```
pub const Inertial = struct {
    // SAFETY: this is overriden in .init()
    var handle: ?*anyopaque = undefined;

    /// A quaternion representing the sensor's orientation in 3D space.
    ///
    /// The quaternion components are:
    /// - `x`, `y`, `z` — the vector part
    /// - `w` — the scalar part
    ///
    /// A unit quaternion (magnitude 1.0) represents a valid rotation.
    pub const InertialQuaternion = struct {
        /// The X component of the quaternion.
        x: f64,
        /// The Y component of the quaternion.
        y: f64,
        /// The Z component of the quaternion.
        z: f64,
        /// The W (scalar) component of the quaternion.
        w: f64,
    };

    /// Initializes an Inertial Sensor on the given port.
    ///
    /// After initialization, call [`reset`] to calibrate the sensor.
    /// Calibration takes approximately 2 seconds.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var imu = velox_sdk.Inertial.init(6);
    /// imu.reset();  // block until calibration completes
    /// ```
    pub fn init(
        /// The smart port number (1–20).
        port: u32,
    ) errors.DeviceInitError!Inertial {
        if (!errors.portIsValid(port))
            return errors.DeviceInitError.InvalidPortError;
        const poolIdx: usize = @intCast(port);
        pool.claim(poolIdx) catch {
            return errors.DeviceInitError.PortUsed;
        };
        return Inertial{
            .handle = jmptbl.devices.vexDeviceGetByIndex(port - 1),
        };
    }

    /// Resets and calibrates the inertial sensor.
    ///
    /// This blocks the current task for approximately 2 seconds while
    /// the sensor calibrates. During calibration, the sensor should
    /// remain stationary.
    ///
    /// ```zig
    /// imu.reset();  // blocks for ~2 seconds
    /// ```
    pub fn reset(self: *const Inertial) void {
        jmptbl.imu.vexDeviceImuReset(self.handle);
    }

    /// Returns the sensor's orientation as a quaternion.
    ///
    /// A unit quaternion (magnitude ≈ 1.0) indicates a valid rotation.
    ///
    /// ```zig
    /// const q = try imu.quat();
    /// // q.x, q.y, q.z, q.w
    /// ```
    pub fn quat(self: *const Inertial) !InertialQuaternion {
        const quaternion: InertialQuaternion = .{};
        jmptbl.imu.vexDeviceImuQuaternionGet(self.handle, &quaternion);
        return quaternion;
    }

    /// Returns the sensor's heading (cumulative rotation) in the
    /// specified units.
    ///
    /// Heading tracks total rotation from the last [`reset`]. It can
    /// exceed 360° / 2π if the sensor rotates multiple times.
    ///
    /// ## Units
    ///
    /// - `.degree` — degrees (cumulative, can exceed 360).
    /// - `.turn` — turns / revolutions (cumulative, can exceed 1.0).
    /// - `.radian` — radians (cumulative, can exceed 2π).
    ///
    /// ```zig
    /// const deg = imu.heading(.degree);
    /// const rad = imu.heading(.radian);
    /// ```
    pub fn heading(self: *const Inertial, unit: units.RotationalUnit) f64 {
        const deg = jmptbl.imu.vexDeviceImuHeadingGet(self.handle);
        return convert.angleFromDegrees(deg, unit);
    }
};
