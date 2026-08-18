//! # Bootup code
//! Contains the signature, bootup sequence, panic handlers, and a zmain

const std = @import("std");
const umm = @import("velox_umm");
const velox_sdk = @import("velox_sdk");
const devices = @import("devices.zig");
const jmptbl = @import("velox_jumptable");
const banner = @import("banner.zig");
const validation = @import("validation.zig");
const vbar = @import("vbar.zig");
const user_code = @import("user_code");

pub const std_options: std.Options = .{
    .page_size_max = 4096,
    .page_size_min = 1,
    .networking = false,
};

// don't compile an invalid user program
comptime {
    validation.validateUserProgram(user_code);
    // Force the exception handler modules to be analyzed so their assembly
    // stubs actually make it into the binary.
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

export const __velox_header__: VeloxHeader = .{
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
        // fp must be 8-aligned and inside mapped RAM
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

    // display calls require the task check-timeslice prolog
    _ = jmptbl.task.vexTaskCheckTimeslice();

    const SCREEN_WIDTH = 480;
    const SCREEN_HEIGHT = 240;

    // if the heap is available, call vex functions
    _ = jmptbl.display.vexDisplayForegroundColor(0xFFFF0000);
    _ = jmptbl.display.vexDisplayRectFill(0, 32, SCREEN_WIDTH, SCREEN_HEIGHT + 32);
    _ = jmptbl.display.vexDisplayForegroundColor(0xFFFFFFFF);
    _ = jmptbl.display.vexDisplayBackgroundColor(0xFFFF0000);

    const PanicLblDimens = getDimensions("------------------ PANIC ------------------");
    printAt("------------------ PANIC ------------------", (SCREEN_WIDTH / 2) - @divFloor(PanicLblDimens.w, 2), 32 + 35 - @divFloor(PanicLblDimens.h, 2));

    _ = jmptbl.display.vexDisplayLineDraw((SCREEN_WIDTH / 2) - @divFloor(PanicLblDimens.w, 2), 32 + 45 + @divFloor(PanicLblDimens.h, 2), SCREEN_WIDTH - ((SCREEN_WIDTH / 2) - @divFloor(PanicLblDimens.w, 2)), 32 + 45 + @divFloor(PanicLblDimens.h, 2));

    const ErrDimens = getDimensions(msg);
    printAt(msg, ((SCREEN_WIDTH / 4) * 3) - @divFloor(ErrDimens.w, 2), (SCREEN_HEIGHT / 2) - @divFloor(ErrDimens.h, 2));
    _ = jmptbl.display.vexDisplayRectDraw(15, 15 + 32, SCREEN_WIDTH - 15, SCREEN_HEIGHT + 32 - 15);

    var arena = std.heap.ArenaAllocator.init(global_alloc.allocator());
    const allocator = arena.allocator();

    const divider_y: i32 = 32 + 45 + @divFloor(PanicLblDimens.h, 2);
    const available_height: i32 = (SCREEN_HEIGHT + 32 - 15) - divider_y;

    var addrs: [32]usize = undefined;
    const n = captureStackTrace(&addrs);

    if (n == 0) {
        printAt("Stack Trace Unavailable", 100, 100);
    } else {
        for (addrs[0..n], 0..) |addr, i| {
            const message = std.fmt.allocPrint(allocator, "0x{x:0>8}", .{addr}) catch {
                @panic("Memory Error");
            };
            const dimens = getDimensions(message);
            const y: i32 = divider_y + 15 + @divFloor(available_height * @as(i32, @intCast(i)), @as(i32, @intCast(n)));
            printAt(message, (SCREEN_WIDTH / 4) - @divFloor(dimens.w, 2), y);
        }
    }

    // we can't/shouldn't use defer because the scope is "noreturn"
    arena.deinit();

    while (true) {
        _ = jmptbl.task.vexTaskSleep(2);
    }
}

// startup the rest of the runtime then call main
export fn __velox_startup__() noreturn {
    // important: DO NOT USE HEAP ALLOCATION HERE
    // clear bss before touching global variables
    @memset(
        @as([*]u8, @ptrCast(&__bss_start))[0 .. @intFromPtr(&__bss_end) - @intFromPtr(&__bss_start)],
        0,
    );

    // setup heap
    const start = @intFromPtr(&__heap_start);
    const end = @intFromPtr(&__heap_end);
    const heap_slice = @as([*]u8, @ptrCast(&__heap_start))[0..(end - start)];

    global_alloc = UmmAllocType.init(heap_slice) catch unreachable;
    // Heap allocation is fine now.
    heap_ok = true;

    // initialize the vector table
    vbar.install_vectors();

    _ = jmptbl.core.vexPrivateApiEnable();
    _ = jmptbl.task.vexTaskAdd(@ptrFromInt(@intFromPtr(&zmain)), 2, "velox");
    while (true) {
        _ = jmptbl.task.vexTasksRun();
    }
}

fn zmain() noreturn {
    banner.printBanner();

    var v5io = velox_sdk.V5Io.init();

    const init: velox_sdk.Init(user_code.ports) = .{
        .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator),
        .gpa = std.heap.DebugAllocator(.{ .thread_safe = true }).init,
        .io = v5io.io(),
        // TODO: Replace this with some code that constructs tha appropriate struct
        .devices = devices.createDevices(user_code.ports),
    };

    user_code.main(init) catch {
        @panic("User code returned");
    };
    // todo maybe VexSystemExitRequest on code exit?
    while (true) {
        _ = jmptbl.task.vexTaskSleep(2);
    }
}
