//! V5 distance sensor (time-of-flight) (§11).

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;
const ports = @import("../ports.zig");
const dev = @import("../internal/dev.zig");

/// A distance sensor on a smart port.
pub const Distance = struct {
    device: ?*anyopaque,
    port: ports.SmartPort,

    /// Create a distance sensor on `port`. The handle is resolved here.
    pub fn init(port: ports.SmartPort) Distance {
        var self = Distance{ .device = null, .port = port };
        self.device = dev.smartDevice(port);
        return self;
    }

    /// Distance to the nearest object, mm. 0 means no object detected.
    pub fn distance(self: *const Distance) u32 {
        const d = self.device orelse return 0;
        return jmptbl.distance.vexDeviceDistanceDistanceGet(d);
    }

    /// Distance to the nearest object, inches.
    pub fn distanceInches(self: *const Distance) f64 {
        return @as(f64, @floatFromInt(self.distance())) / 25.4;
    }

    /// Sensor confidence, 0..100 percent.
    pub fn confidence(self: *const Distance) f64 {
        const d = self.device orelse return 0.0;
        return std.math.clamp(@as(f64, @floatFromInt(jmptbl.distance.vexDeviceDistanceConfidenceGet(d))), 0.0, 100.0);
    }

    /// Velocity of the nearest object, meters/second (positive = toward
    /// the sensor). 0 when no object is moving.
    pub fn objectVelocity(self: *const Distance) f64 {
        const d = self.device orelse return 0.0;
        return jmptbl.distance.vexDeviceDistanceObjectVelocityGet(d);
    }

    /// Relative size of the nearest object, 0..100 percent.
    pub fn objectSize(self: *const Distance) f64 {
        const d = self.device orelse return 0.0;
        return std.math.clamp(@as(f64, @floatFromInt(jmptbl.distance.vexDeviceDistanceObjectSizeGet(d))), 0.0, 100.0);
    }

    /// True when the distance read reports an object.
    pub fn hasDetectedObject(self: *const Distance) bool {
        return self.distance() != 0;
    }

    /// True when the port is claimed and the OS reports a distance
    /// sensor there (§18.1).
    pub fn isConnected(self: *const Distance) bool {
        if (self.device == null) return false;
        return dev.smartPortTypeIs(self.port, types.V5_DeviceType.kDeviceTypeDistanceSensor);
    }
};
