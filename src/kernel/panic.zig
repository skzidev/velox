const std = @import("std");
const serial = @import("serial");
const jmptbl = @import("jumptable");
const faults = @import("vectors/fault.zig");

/// Print the stack trace at a specified address until it leaves user memory space.
fn printStackTrace(frameAddr: usize) void {
    var fp = frameAddr;
    var count: usize = 0;
    while (fp != 0 and count < 32) : (count += 1) {
        if (fp < 0x0340_0000 or fp >= 0x0800_0000 or (fp & 0x3) != 0) break;
        const frame: *const [2]usize = @ptrFromInt(fp);
        const saved_fp = frame[0];
        const saved_lr = frame[1];

        var line_buf: [64]u8 = undefined;
        const line = std.fmt.bufPrint(&line_buf, "    0x{x:0>8} (frame {d})\n", .{
            saved_lr,
            count,
        }) catch "    0x???????? (unknown frame)\n";
        serial.write(line) catch {};

        if (saved_fp <= fp) break;
        fp = saved_fp;
    }
}

/// Zig panic handler implementation, since normal panics will cause CPU faults on the Brain.
pub fn panicHook(
    msg: []const u8,
    _: ?*std.builtin.StackTrace,
    _: ?usize,
) noreturn {
    var buffer: [4096]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buffer);
    const alloc = fba.allocator();

    const message = std.fmt.allocPrint(alloc, "panic: '{s}'\nStack trace:\n", .{msg}) catch "panic: 'Unprintable exception'. Stack trace:\n";
    serial.write(message) catch {};

    printStackTrace(@frameAddress());

    serial.flush();

    while (true) {
        _ = jmptbl.vexTasksRun();
    }
}

// Fault handler implementation.
pub fn faultPanic(fault: *const faults.Fault, msg: []const u8) noreturn {
    var buffer: [4096]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buffer);
    const alloc = fba.allocator();

    const message = alloc.print("fault: '{s}'\nStack Trace:\n", .{msg}) catch "fault: unidentifiable CPU fault\nStack Trace:\n";
    serial.write(message) catch {};

    printStackTrace(fault.stack_pointer);

    serial.write("Register Dump:\n") catch {};

    for (fault.registers, 0..) |register, idx| {
        const line = alloc.print("  r{d}={x:0>8}", .{ idx, register }) catch "  r?=0x????????";
        serial.write(line) catch {};
        alloc.free(line);
    }

    serial.flush();

    while (true) {
        _ = jmptbl.vexTasksRun();
    }
}
