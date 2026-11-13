const std = @import("std");
const serial = @import("io/serial.zig");

pub fn panicHook(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
) noreturn {
    serial.write(msg);
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {}
}
