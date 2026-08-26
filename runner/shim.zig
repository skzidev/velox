const std = @import("std");

pub const std_options = std.Options{
    .page_size_max = 4096,
    .page_size_min = 4096,
    .networking = false,
};

fn noopAlloc(_: *anyopaque, _: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
    @panic("shim: unused");
}

fn noopResize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
    @panic("shim: unused");
}

fn noopRemap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
    @panic("shim: unused");
}

fn noopFree(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
    @panic("shim: unused");
}

pub const os = struct {
    pub const heap = struct {
        pub const page_allocator: std.mem.Allocator = .{
            .ptr = undefined,
            .vtable = &.{
                .alloc = noopAlloc,
                .resize = noopResize,
                .remap = noopRemap,
                .free = noopFree,
            },
        };
    };
};

pub fn main() void {}
