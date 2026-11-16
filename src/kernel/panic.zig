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

    const message = allocator.print("panic: {s}\n", .{msg}) catch "Unprintable exception";
    serial.write(message) catch {};

    if (error_return_trace) |stack_trace| {
        for (stack_trace.instruction_addresses) |address| {
            const m = allocator.print("  at 0x{x:0>8}\n", .{
                address,
            }) catch "  at 0x????????";
            defer allocator.free(m);
            serial.write(m) catch {};
        }
    }

    allocator.free(message);

    _ = ret_addr;
    while (true) {
        _ = jmptbl.vexTasksRun();
    }
}
