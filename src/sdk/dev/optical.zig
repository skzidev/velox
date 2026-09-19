//! V5 optical sensor (§12). The photogate's white LED has intensity
//! control only; per-color LED settings are a documented no-op.

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;
const ports = @import("../ports.zig");
const dev = @import("../internal/dev.zig");

/// An RGB color, each channel in [0, 1].
pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
};

/// An optical sensor on a smart port.
pub const Optical = struct {
    device: ?*anyopaque,
    port: ports.SmartPort,

    /// Create an optical sensor on `port`. The handle is resolved here.
    pub fn init(port: ports.SmartPort) Optical {
        var self = Optical{ .device = null, .port = port };
        self.device = dev.smartDevice(port);
        return self;
    }

    /// Object proximity, 0..100 percent. 0 means nothing is in range.
    pub fn proximity(self: *const Optical) f64 {
        const d = self.device orelse return 0.0;
        return std.math.clamp(@as(f64, @floatFromInt(jmptbl.optical.vexDeviceOpticalProximityGet(d))), 0.0, 100.0);
    }

    /// Ambient brightness, 0..100 percent. The OS reports a normalized
    /// 0..1 value; the scaling factor is hardware-pinned in §12.1.
    pub fn brightness(self: *const Optical) f64 {
        const d = self.device orelse return 0.0;
        return std.math.clamp(jmptbl.optical.vexDeviceOpticalBrightnessGet(d) * 100.0, 0.0, 100.0);
    }

    /// The detected color, red/green/blue each normalized to [0, 1].
    /// The raw RGB buffer is [red, green, blue, clear] (§12.1).
    pub fn color(self: *const Optical) Color {
        const d = self.device orelse return .{ .r = 0.0, .g = 0.0, .b = 0.0 };
        var rgb: [4]f64 = undefined;
        jmptbl.optical.vexDeviceOpticalRgbGet(d, @ptrCast(&rgb));
        return .{
            .r = std.math.clamp(@as(f32, @floatCast(rgb[0])), 0.0, 1.0),
            .g = std.math.clamp(@as(f32, @floatCast(rgb[1])), 0.0, 1.0),
            .b = std.math.clamp(@as(f32, @floatCast(rgb[2])), 0.0, 1.0),
        };
    }

    /// True when an object is in sensing range.
    pub fn hasDetectedObject(self: *const Optical) bool {
        return self.proximity() > 0.0;
    }

    /// Set the intensity of the photogate's white LED, 0..100 percent.
    pub fn setLedBrightness(self: *const Optical, percentage: f64) void {
        const d = self.device orelse return;
        const pwm = std.math.clamp(percentage, 0.0, 100.0);
        jmptbl.optical.vexDeviceOpticalLedPwmSet(d, @intFromFloat(std.math.round(pwm)));
    }

    /// Adjust the LED's color. Documented no-op: this sensor's LED is
    /// white only, and the OS exposes only intensity (§12.1).
    pub fn setLedColor(self: *const Optical, c: Color) void {
        _ = self;
        _ = c;
    }

    /// True when the port is claimed and the OS reports an optical
    /// sensor there (§18.1).
    pub fn isConnected(self: *const Optical) bool {
        if (self.device == null) return false;
        return dev.smartPortTypeIs(self.port, types.V5_DeviceType.kDeviceTypeOpticalSensor);
    }
};
