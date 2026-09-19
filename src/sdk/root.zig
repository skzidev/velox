const std = @import("std");

pub const units = @import("units.zig");
pub const ports = @import("ports.zig");

pub const Motor = @import("dev/motor.zig").Motor;
pub const Rotation = @import("dev/rotation.zig").Rotation;
pub const Inertial = @import("dev/inertial.zig").Inertial;
pub const Distance = @import("dev/distance.zig").Distance;
pub const Optical = @import("dev/optical.zig").Optical;

pub const adi = @import("dev/adi.zig");
pub const Bumper = adi.Bumper;
pub const LimitSwitch = adi.LimitSwitch;
pub const LineTracker = adi.LineTracker;
pub const Potentiometer = adi.Potentiometer;
pub const AnalogInput = adi.AnalogInput;
pub const AnalogOutput = adi.AnalogOutput;
pub const DigitalInput = adi.DigitalInput;
pub const DigitalOutput = adi.DigitalOutput;
pub const Ultrasonic = adi.Ultrasonic;
pub const Solenoid = adi.Solenoid;
pub const Pneumatic = adi.Pneumatic;
pub const DoubleSolenoid = adi.DoubleSolenoid;

pub const Controller = @import("controller.zig").Controller;
pub const Display = @import("display.zig").Display;
pub const Battery = @import("battery.zig").Battery;
pub const Competition = @import("competition.zig").Competition;

pub const V5Io = @import("Io.zig").V5Io;

pub const Init = struct {
    arena: std.heap.ArenaAllocator,
    gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 6, .enable_memory_limit = false, .safety = true, .thread_safe = true, .never_unmap = false, .retain_metadata = false, .verbose_log = false, .backing_allocator_zeroes = true, .resize_stack_traces = false, .canary = 2246045967, .page_size = 131072 }),
    io: std.Io,
};

test {
    std.testing.refAllDecls(@This());
}
