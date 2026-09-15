const std = @import("std");

pub const Motor = @import("dev/smart/motor.zig").Motor;
pub const Unit = struct {
    Power: type = @import("units/power.zig").PowerUnit,
    Velocity: type = @import("units/velocity.zig").VelocityUnits,
    Angle: type = @import("units/angle.zig").AngleUnits,
};

pub const V5Io = @import("Io.zig").V5Io;

pub const Init = struct {
    arena: std.heap.ArenaAllocator,
    gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 6, .enable_memory_limit = false, .safety = true, .thread_safe = true, .never_unmap = false, .retain_metadata = false, .verbose_log = false, .backing_allocator_zeroes = true, .resize_stack_traces = false, .canary = 2246045967, .page_size = 131072 }),
    io: std.Io,
};
