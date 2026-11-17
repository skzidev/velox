const std = @import("std");
const serial = @import("io/serial.zig");
const jmptbl = @import("jumptable");

/// Zig panic handler implementation, since normal panics will cause CPU faults on the Brain.
pub fn panicHook(
    msg: []const u8,
    _: ?*std.builtin.StackTrace,
    _: ?usize,
) noreturn {
    var buffer: [4096]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buffer);
    var allocator = fba.allocator();

    const message = allocator.print("panic: '{s}'. Stack trace:\n", .{msg}) catch "panic: 'Unprintable exception'. Stack trace:\n";
    serial.write(message) catch {};

    var fp = @frameAddress();
    var count: usize = 0;
    while (fp != 0 and count < 32) {
        if (fp < 0x03400000 or fp >= 0x08000000 or (fp & 0x7) != 0) break;
        const frame: *const [2]usize = @ptrFromInt(fp);
        const saved_fp = frame[0];
        const saved_lr = frame[1];

        const m = allocator.print("    0x{x:0>8} (frame {d})\n", .{
            saved_lr,
            count,
        }) catch "    0x???????? (unknown frame)\n";
        serial.write(m) catch {};
        allocator.free(m);

        count += 1;
        if (saved_fp <= fp) break;
        fp = saved_fp;
    }

    allocator.free(message);

    while (true) {
        _ = jmptbl.vexTasksRun();
    }
}
