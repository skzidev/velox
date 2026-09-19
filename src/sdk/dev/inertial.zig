//! V5 inertial sensor (IMU) (§10).
//!
//! Setup direction is fixed at +Z (front of the sensor body); the raw
//! attitude layout and axis ordering are hardware-pinned in §10.1 before
//! release. All vector components are canonical SI-ish units: g for
//! acceleration, degrees/second for angular rate.

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;
const ports = @import("../ports.zig");
const dev = @import("../internal/dev.zig");

/// Calibration polling budget: at most this many milliseconds before
/// `resetAndCalibrate` gives up (≈2 s expected on hardware).
const calibrate_timeout_ms: u32 = 3000;
const poll_step_ms: u32 = 20;

pub const Vector3 = struct {
    x: f64,
    y: f64,
    z: f64,
};

/// Calibration state reported by the sensor (§10.4).
pub const Status = enum(u8) {
    not_calibrated,
    calibrating,
    calibrated,
};

/// An IMU on a smart port.
pub const Inertial = struct {
    device: ?*anyopaque,
    port: ports.SmartPort,

    /// Create an IMU on `port` (setup direction: +Z forward, §10.1).
    pub fn init(port: ports.SmartPort) Inertial {
        var self = Inertial{ .device = null, .port = port };
        self.device = dev.smartDevice(port);
        return self;
    }

    /// Begin calibration, then block the calling task until the sensor
    /// reports calibrated (budget ≈2 s, hard-capped at `calibrate_timeout_ms`).
    /// When unclaimed, returns immediately; never blocks forever (§10.3).
    pub fn resetAndCalibrate(self: *const Inertial) void {
        const d = self.device orelse return;
        jmptbl.imu.vexDeviceImuReset(d);
        var elapsed: u32 = 0;
        while (calibratingRaw(d) and elapsed < calibrate_timeout_ms) {
            jmptbl.task.vexTaskSleep(poll_step_ms);
            elapsed += poll_step_ms;
        }
    }

    /// Begin calibration without blocking (§10.3); poll `status()`.
    pub fn startCalibration(self: *const Inertial) void {
        const d = self.device orelse return;
        jmptbl.imu.vexDeviceImuReset(d);
    }

    /// Calibration status (§10.4). Bits are documented in §10.1.
    pub fn status(self: *const Inertial) Status {
        const d = self.device orelse return .not_calibrated;
        return statusFromRaw(jmptbl.imu.vexDeviceImuStatusGet(d));
    }

    /// Cumulative heading, degrees, from the sensor's zeroed orientation.
    /// May exceed ±180° with repeated rotation (§10.5) and reads zero
    /// while calibrating.
    pub fn heading(self: *const Inertial) f64 {
        const d = self.device orelse return 0.0;
        return jmptbl.imu.vexDeviceImuHeadingGet(d);
    }

    /// Heading, radians, equivalent to `heading()`.
    pub fn headingRadians(self: *const Inertial) f64 {
        return self.heading() * std.math.pi / 180.0;
    }

    /// Current yaw angle (heading), wrapped to [-180, 180) degrees.
    pub fn yaw(self: *const Inertial) f64 {
        return @mod(self.heading() + 180.0, 360.0) - 180.0;
    }

    /// Pitch angle, degrees (from the attitude buffer, in [yaw, pitch,
    /// roll] order; axis ordering hardware-pinned in §10.1).
    pub fn pitch(self: *const Inertial) f64 {
        const d = self.device orelse return 0.0;
        var attitude: [3]f64 = undefined;
        jmptbl.imu.vexDeviceImuAttitudeGet(d, @ptrCast(&attitude));
        return attitude[1];
    }

    /// Roll angle, degrees.
    pub fn roll(self: *const Inertial) f64 {
        const d = self.device orelse return 0.0;
        var attitude: [3]f64 = undefined;
        jmptbl.imu.vexDeviceImuAttitudeGet(d, @ptrCast(&attitude));
        return attitude[2];
    }

    /// Linear acceleration, in units of g (each component separate).
    pub fn acceleration(self: *const Inertial) Vector3 {
        const d = self.device orelse return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        var raw: [3]f64 = undefined;
        jmptbl.imu.vexDeviceImuRawAccelGet(d, @ptrCast(&raw));
        return .{ .x = raw[0], .y = raw[1], .z = raw[2] };
    }

    /// Angular rate, degrees/second.
    pub fn gyro(self: *const Inertial) Vector3 {
        const d = self.device orelse return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        var raw: [3]f64 = undefined;
        jmptbl.imu.vexDeviceImuRawGyroGet(d, @ptrCast(&raw));
        return .{ .x = raw[0], .y = raw[1], .z = raw[2] };
    }

    /// True when the port is claimed and the OS reports an IMU there (§18.1).
    pub fn isConnected(self: *const Inertial) bool {
        if (self.device == null) return false;
        return dev.smartPortTypeIs(self.port, types.V5_DeviceType.kDeviceTypeImuSensor);
    }
};

/// Raw status register bits: calibrating = 0x04, calibrated/ready = 0x02.
fn statusFromRaw(raw: u32) Status {
    if ((raw & 0x4) != 0) return .calibrating;
    if ((raw & 0x2) != 0) return .calibrated;
    return .not_calibrated;
}

fn calibratingRaw(d: ?*anyopaque) bool {
    return statusFromRaw(jmptbl.imu.vexDeviceImuStatusGet(d)) == .calibrating;
}
