//! V5 rotation sensor (an absolute shaft encoder) (§9).
//!
//! The sensor's raw units are hardware-pinned in §9.1 (one hardware
//! resolution is documented there); this SDK reports canonical degrees,
//! rpm, and [0°, 360°) angle, following the common V5 convention of one
//! raw unit = 0.01° / 0.01 rpm. A hardware calibration test must pin the
//! exact factor before release.

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;
const ports = @import("../ports.zig");
const units = @import("../units.zig");
const convert = @import("../internal/convert.zig");
const dev = @import("../internal/dev.zig");

/// Raw units per degree (raw value / 100; §9.1, hardware-pin pending).
const raw_per_unit: f64 = 100.0;

/// A rotation sensor on a smart port.
pub const Rotation = struct {
    device: ?*anyopaque,
    port: ports.SmartPort,

    /// Create a rotation sensor on `port`, defaulting to forward
    /// mounting and a 10 ms data rate (§9.1). The handle is resolved
    /// here; the defaults are written only if the port is claimed.
    pub fn init(port: ports.SmartPort) Rotation {
        var self = Rotation{ .device = null, .port = port };
        const d = dev.smartDevice(port) orelse return self;
        self.device = d;
        jmptbl.rotation.vexDeviceAbsEncReverseFlagSet(d, 0);
        jmptbl.rotation.vexDeviceAbsEncDataRateSet(d, 10);
        return self;
    }

    /// Total angular position, degrees (unwrapped).
    pub fn position(self: *const Rotation) f64 {
        const d = self.device orelse return 0.0;
        return @as(f64, @floatFromInt(jmptbl.rotation.vexDeviceAbsEncPositionGet(d))) / raw_per_unit;
    }

    /// Absolute angle, wrapped to [0, 360) degrees.
    pub fn angle(self: *const Rotation) f64 {
        return @mod(self.position(), 360.0);
    }

    /// Rotational velocity, rpm.
    pub fn velocity(self: *const Rotation) f64 {
        const d = self.device orelse return 0.0;
        return @as(f64, @floatFromInt(jmptbl.rotation.vexDeviceAbsEncVelocityGet(d))) / raw_per_unit;
    }

    /// Zero the sensor's total position (§9.4).
    pub fn reset(self: *const Rotation) void {
        const d = self.device orelse return;
        jmptbl.rotation.vexDeviceAbsEncReset(d);
    }

    /// Set the encoder position to `position` (§9.3).
    pub fn setPosition(self: *const Rotation, target: units.Position) void {
        const d = self.device orelse return;
        const degrees = convert.positionToDegrees(target);
        jmptbl.rotation.vexDeviceAbsEncPositionSet(d, @intFromFloat(std.math.round(degrees * raw_per_unit)));
    }

    /// Reverse the sensor's positive direction (§9.2).
    pub fn setReversed(self: *const Rotation, reverse: bool) void {
        const d = self.device orelse return;
        jmptbl.rotation.vexDeviceAbsEncReverseFlagSet(d, @intFromBool(reverse));
    }

    /// Set the sensor's data rate in milliseconds; values below 1 are
    /// clamped up to 1 (§9.1).
    pub fn setDataRate(self: *const Rotation, rate_ms: u32) void {
        const d = self.device orelse return;
        jmptbl.rotation.vexDeviceAbsEncDataRateSet(d, @max(rate_ms, 1));
    }

    /// True when the port is claimed and the OS reports an absolute
    /// encoder there (§18.1).
    pub fn isConnected(self: *const Rotation) bool {
        if (self.device == null) return false;
        return dev.smartPortTypeIs(self.port, types.V5_DeviceType.kDeviceTypeAbsEncSensor);
    }
};
