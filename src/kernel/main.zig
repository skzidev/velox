const jmptbl = @import("jumptable");
const codeRoot = @import("code_root");
const std = @import("std");
const juicyMain = @import("interfaces/juicy.zig");
const ioInterface = @import("interfaces/io.zig");
const serial = @import("io/serial.zig");

fn doesAcceptJuicyMain(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"fn") return false;

    const fn_info = info.@"fn";
    if (fn_info.param_types.len != 1) return false;
    if (fn_info.param_types[0] != juicyMain.Init) return false;
    return true;
}

pub fn vmain() callconv(.c) i32 {
    const gpa: std.heap.DebugAllocator(.{}) = .init;
    const arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

    serial.write("hello world!\n") catch {};

    if (comptime doesAcceptJuicyMain(@TypeOf(codeRoot.main))) {
        codeRoot.main(juicyMain.Init{
            .gpa = gpa,
            .arena = arena,
            .io = ioInterface.Io{},
        });
    } else {
        codeRoot.main();
    }

    codeRoot.main();
    return 0;
}
