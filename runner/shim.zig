const std = @import("std");

pub const std_options = std.Options{
    .page_size_max = 4096,
    .page_size_min = 4096,
    .networking = false,
};

var page_buf: [1024 * 64]u8 = undefined;
var page_fba = std.heap.FixedBufferAllocator.init(&page_buf);

pub const os = struct {
    pub const heap = struct {
        pub const page_allocator = page_fba.allocator();
    };
};

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}

pub fn main() void {}
