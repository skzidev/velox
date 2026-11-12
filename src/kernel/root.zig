const umm = @import("umm");
const std = @import("std");
const jmptbl = @import("jumptable");
const main = @import("main.zig");
const codeRoot = @import("code_root");

extern var _heap_start: u8;
extern var _heap_end: u8;

extern var _vector_table: u8;

export fn velox_startup() callconv(.c) noreturn {
    // setup heap allocator
    const heapStart = @intFromPtr(&_heap_start);
    const heapEnd = @intFromPtr(&_heap_end);
    const heapSlice = @as([*]u8, @ptrCast(&_heap_start))[0..(heapEnd - heapStart)];

    global_alloc = AllocatorType.init(heapSlice) catch {
        @panic("Could not initialize heap allocator");
    };

    // setup vbar
    asm volatile ("dsb" ::: .{ .memory = true });
    const vbar_addr: u32 = @intFromPtr(&_vector_table);
    asm volatile ("mcr p15, 0, %[addr], c12, c0, 0"
        :
        : [addr] "r" (vbar_addr),
        : .{ .memory = true });
    asm volatile ("isb" ::: .{ .memory = true });

    jmptbl.vexPrivateApiEnable();

    // start loading main task
    _ = jmptbl.vexTaskAdd(&main.vmain, 2, "velox_main");
    while (true) {
        _ = jmptbl.vexTasksRun();
    }
}

comptime {
    _ = @import("vectors/fault.zig");
}

pub const std_options = std.Options{
    .networking = false,
    .page_size_max = 4096,
    .page_size_min = 4096,
};

const AllocatorType = umm.UmmAllocator(.{});
// SAFETY: this is initialized after bss is cleared
var global_alloc: AllocatorType = undefined;

pub const os = struct {
    pub const heap = struct {
        pub const page_allocator = global_alloc.allocator();
    };
};

pub const panic = &(@import("panic.zig").panicHook);
