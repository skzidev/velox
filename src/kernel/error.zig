const vsdk = @import("velox_sdk");
const std = @import("std");
const jmptbl = @import("velox_jumptable");

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    var v5io: vsdk.V5Io = .init();
    const io = v5io.io();
    const heapAllocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const gpa = heapAllocator.allocator();

    const idx = jmptbl.task.vexTaskGetIndex();
    const message = std.fmt.allocPrint(gpa, "thread {d} panic: {s}", .{ idx, msg }) catch "Panic encountered.";

    const stderr = vsdk.V5Io.File.stderr();
    stderr.writeStreamingAll(io, message);
}
