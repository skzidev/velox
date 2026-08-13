//! Fault handlers.
//!
//! Handles undefined instruction, prefetch abort, and data abort exceptions.
//! These are always fatal: Velox captures the CPU state, prints a report over
//! serial, and asks VEXos to exit.

const std = @import("std");
const jmptbl = @import("velox_jumptable");

pub const FaultCause = enum(u32) {
    undefined_instruction = 0,
    prefetch_abort = 1,
    data_abort = 2,
};

pub const Fault = extern struct {
    link_register: u32,
    stack_pointer: u32,
    cause: FaultCause,
    cpsr: u32,
    program_counter: u32,
    registers: [13]u32,
};

comptime {
    asm (
        \\.section .text.handlers, "ax"
        \\.arm
        \\.align 2
        \\.global fault_handler_undef
        \\fault_handler_undef:
        \\  dsb
        \\  movw sp, #:lower16:__abort_stack_top
        \\  movt sp, #:upper16:__abort_stack_top
        \\  push {r0-r12}
        \\  mov r0, #0
        \\  mrs r1, spsr
        \\  tst r1, #0x20
        \\  subeq lr, #4
        \\  subne lr, #2
        \\  b fault_common
        \\.global fault_handler_pabort
        \\fault_handler_pabort:
        \\  dsb
        \\  movw sp, #:lower16:__abort_stack_top
        \\  movt sp, #:upper16:__abort_stack_top
        \\  push {r0-r12}
        \\  mov r0, #1
        \\  mrs r1, spsr
        \\  sub lr, #4
        \\  b fault_common
        \\.global fault_handler_dabort
        \\fault_handler_dabort:
        \\  dsb
        \\  movw sp, #:lower16:__abort_stack_top
        \\  movt sp, #:upper16:__abort_stack_top
        \\  push {r0-r12}
        \\  mov r0, #2
        \\  mrs r1, spsr
        \\  sub lr, #8
        \\  b fault_common
        \\fault_common:
        \\  push {r0, r1, lr}     @ cause, spsr, program counter
        \\  stmdb sp, {sp}^       @ original system/user stack pointer
        \\  sub sp, sp, #4
        \\  stmdb sp, {lr}^       @ original system/user link register
        \\  sub sp, sp, #4
        \\  mov r0, sp            @ param 0 = *Fault
        \\  bl __velox_fault_handler__
        \\  b .                   @ never returns; spin just in case
    );
}

fn writeSerial(msg: []const u8) void {
    _ = jmptbl.serial.vexSerialWriteBuffer(1, @constCast(msg.ptr), msg.len);
}

fn faultAddress(fault: *const Fault) u32 {
    return switch (fault.cause) {
        .undefined_instruction => fault.program_counter,
        .data_abort => asm volatile ("mrc p15, 0, %[addr], c6, c0, 0" // DFAR
            : [addr] "=r" (-> u32),
        ),
        .prefetch_abort => asm volatile ("mrc p15, 0, %[addr], c6, c0, 2" // IFAR
            : [addr] "=r" (-> u32),
        ),
    };
}

export fn __velox_fault_handler__(fault: *Fault) noreturn {
    const cause: []const u8 = switch (fault.cause) {
        .undefined_instruction => "undefined instruction",
        .prefetch_abort => "prefetch abort",
        .data_abort => "data abort",
    };

    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "velox: fatal {s} at 0x{x:0>8}\n  pc = 0x{x:0>8}\n  lr = 0x{x:0>8}\n  sp = 0x{x:0>8}\n", .{
        cause,
        faultAddress(fault),
        fault.program_counter,
        fault.link_register,
        fault.stack_pointer,
    }) catch "velox: fatal fault (unable to format report)";
    writeSerial(msg);

    jmptbl.system.vexSystemExitRequest();
    while (true) {
        asm volatile ("nop");
    }
}
