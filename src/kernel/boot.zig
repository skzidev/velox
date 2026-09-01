//! # Bootup code
//! Contains the signature, bootup sequence, panic handlers, and a zmain

// zlint-disable unused-decls -- __velox_header__ and others must be there to make the brain boot the image

const std = @import("std");
const umm = @import("velox_umm");
const velox_sdk = @import("velox_sdk");
const jmptbl = @import("velox_jumptable");
const banner = @import("banner.zig");
const validation = @import("validation.zig");
const vbar = @import("vbar.zig");
const user_code = @import("user_code");

pub const std_options = std.Options{
    // this setting is required because of how umm works.
    // in Zig, page_allocator just grabs huge chunks of memory (4096 bytes)
    // and then other allocators sit on top of it and carve out smaller chunks.
    // this essentially ensures that memory is allocated in 4096 blocks.
    .page_size_max = 4096,
    .page_size_min = 4096,
    // the v5 brain doesn't have wifi, so we want to prevent users from breaking things
    // by trying to use networking.
    .networking = false,
};

// don't compile an invalid user program
comptime {
    validation.validateUserProgram(user_code);

    _ = @import("handlers/fault.zig");
    _ = @import("handlers/irq.zig");
    _ = @import("handlers/fiq.zig");
    _ = @import("handlers/svc.zig");
}

const VeloxHeader = extern struct {
    sig: u32,
    type: u32,
    owner: u32,
    flags: u32,
    reserved_1: u32,
    reserved_2: u32,
    reserved_3: u32,
    reserved_4: u32,
};

export const __velox_header__ = VeloxHeader{
    .sig = 0x56355347,
    .type = 0x00000000,
    .owner = 0x00000002,
    .flags = 0x00000000,
    .reserved_1 = 0x00000000,
    .reserved_2 = 0x00000000,
    .reserved_3 = 0x00000000,
    .reserved_4 = 0x00000000,
};

// tell backtrace to stop here, initialize stack pointer, call startup.
export fn __velox_boot__() linksection(".__velox_boot__") callconv(.naked) noreturn {
    asm volatile (
        \\ mov fp, #0
        \\ mov r7, #0
        \\ ldr sp, =__stack_top
        \\ blx __velox_startup__
    );
}

extern var __heap_start: u8;
extern var __heap_end: u8;
extern var __bss_start: u8;
extern var __bss_end: u8;

const UmmAllocType = umm.UmmAllocator(.{});

// SAFETY: this is initalized after bss is cleared
var global_alloc: UmmAllocType = undefined;
var heap_ok: bool = false;

// override the default stdlib page allocator with umm
pub const os = struct {
    pub const heap = struct {
        pub const page_allocator = global_alloc.allocator();
    };
};

// small helper function just for writing text to the screen. this should only be used here.
fn printAt(msg: []const u8, x: i32, y: i32) void {
    const c_ptr: [*:0]const u8 = @ptrCast(msg.ptr);
    _ = jmptbl.display.vexDisplayPrintf(x, y, 255, c_ptr);
}

const DimenType = struct { w: i32, h: i32 };

fn getDimensions(msg: []const u8) DimenType {
    const c_ptr: [*:0]const u8 = @ptrCast(msg.ptr);
    return DimenType{
        .w = jmptbl.display.vexDisplayStringWidthGet(c_ptr),
        .h = jmptbl.display.vexDisplayStringHeightGet(c_ptr),
    };
}

var hasPanicked: bool = false;

fn captureStackTrace(addrs: []usize) usize {
    var fp: usize = @frameAddress();
    var count: usize = 0;
    while (fp != 0 and count < addrs.len) {
        // fp must be 8-aligned and inside user ram
        if (fp < 0x03400000 or fp >= 0x08000000 or (fp & 0x7) != 0) break;
        const frame: *const [2]usize = @ptrFromInt(fp);
        const saved_fp = frame[0];
        const saved_lr = frame[1];
        addrs[count] = saved_lr;
        count += 1;
        if (saved_fp <= fp) break; // frames ascend toward the top of the stack
        fp = saved_fp;
    }
    return count;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // crash if the heap is unavailable
    if (!heap_ok or hasPanicked) {
        jmptbl.system.vexSystemExitRequest();
        while (true) _ = jmptbl.task.vexTaskSleep(2);
    }
    hasPanicked = true;

    // This is a test. This should be replaced with printing actual information to the brain and to the brain screen.
    _ = jmptbl.serial.vexSerialWriteBuffer(1, @ptrCast(@constCast("issue found")), msg.len);

    while (true) {
        _ = jmptbl.task.vexTaskSleep(2);
    }
}

// The main function blocks
// this is because autonomous code should never start until calibration of sensors is done
var main_finished = false;

// startup the rest of the runtime then call main
export fn __velox_startup__() noreturn {
    heap_ok = false;
    // clear bss before touching global variables
    @memset(
        @as([*]u8, @ptrCast(&__bss_start))[0 .. @intFromPtr(&__bss_end) - @intFromPtr(&__bss_start)],
        0,
    );

    // setup heap
    const start = @intFromPtr(&__heap_start);
    const end = @intFromPtr(&__heap_end);
    const heap_slice = @as([*]u8, @ptrCast(&__heap_start))[0..(end - start)];

    global_alloc = UmmAllocType.init(heap_slice) catch {
        @panic("Cannot initalize heap allocator");
    };
    heap_ok = true;

    // initialize the vector table
    vbar.install_vectors();

    jmptbl.core.vexPrivateApiEnable();
    _ = jmptbl.task.vexTaskAdd(@ptrFromInt(@intFromPtr(&zmain)), 2, "velox_main");
    while (true) {
        _ = jmptbl.task.vexTasksRun();
    }
}

fn zmain() noreturn {
    banner.printBanner();
    banner.serialFlush();

    var v5io = velox_sdk.V5Io.init();

    const init: velox_sdk.Init = .{
        .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
        .gpa = std.heap.DebugAllocator(.{ .thread_safe = true }).init,
        .io = v5io.io(),
    };

    user_code.main(init) catch {
        _ = jmptbl.serial.vexSerialWriteBuffer(1, @ptrCast(@constCast("error encountered")), 16);
        banner.serialFlush();
        jmptbl.system.vexSystemExitRequest();
    };
    main_finished = true;
    while (true) {
        _ = jmptbl.task.vexTaskSleep(2);
    }
}
