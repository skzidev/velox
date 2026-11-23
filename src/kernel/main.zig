const jmptbl = @import("jumptable");
const codeRoot = @import("code_root");
const std = @import("std");
const serial = @import("serial");

pub fn vmain() callconv(.c) i32 {
    // const gpa: std.heap.DebugAllocator(.{}) = .init;
    // const arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

    serial.write("hello world!\n") catch {};

    codeRoot.main();

    return 0;
}
