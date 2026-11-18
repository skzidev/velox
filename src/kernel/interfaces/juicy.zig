const std = @import("std");
const io = @import("io.zig");

pub const Init = struct {
    gpa: std.heap.DebugAllocator(.{
        .backing_allocator_zeroes = true,
    }),
    arena: std.heap.ArenaAllocator,
    io: io.Io,
};
