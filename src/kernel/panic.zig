const std = @import("std");
const serial = @import("io/serial.zig");
const jmptbl = @import("jumptable");

/// Zig panic handler implementation, since normal panics will cause CPU faults on the Brain.
pub fn panicHook(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
) noreturn {
    var buffer: [4096]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buffer);
    var allocator = fba.allocator();

    const taskIndex = jmptbl.vexTaskGetIndex();
    const message = allocator.print("task {d} panic: {s}\n", .{ taskIndex, msg }) catch "Unprintable exception";
    serial.write(message);

    if (error_return_trace) |stack_trace| {
        for (stack_trace.instruction_addresses) |address| {
            const m = allocator.print("  at 0x{x:0>8}{s}\n", .{
                address,
                if (stack_trace.index == address) " (current address)" else "",
            }) catch "  at an unprintable address";
            defer allocator.free(m);
            serial.write(m);
        }
    }

    allocator.free(message);

    _ = ret_addr;
    while (true) {}
}
