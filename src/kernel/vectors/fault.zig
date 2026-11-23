const std = @import("std");
const panics = @import("../panic.zig");

pub const FaultCause = enum(u32) {
    undefined_instruction = 0,
    prefetch_abort = 1,
    data_abort = 2,
};

// ARM fault struct; layout must match fault.s stack frame.
// fault.s pushes r0-r12, then {cause,cpsr,lr_adjusted}, then user {sp,lr}.
pub const Fault = extern struct {
    link_register: u32,
    stack_pointer: u32,
    cause: FaultCause,
    cpsr: u32,
    program_counter: u32,
    registers: [13]u32,
};

comptime {
    if (@offsetOf(Fault, "link_register") != 0) @compileError("Fault.link_register offset");
    if (@offsetOf(Fault, "stack_pointer") != 4) @compileError("Fault.stack_pointer offset");
    if (@offsetOf(Fault, "cause") != 8) @compileError("Fault.cause offset");
    if (@offsetOf(Fault, "cpsr") != 12) @compileError("Fault.cpsr offset");
    if (@offsetOf(Fault, "program_counter") != 16) @compileError("Fault.program_counter offset");
    if (@offsetOf(Fault, "registers") != 20) @compileError("Fault.registers offset");
    if (@sizeOf(Fault) != 72) @compileError("Fault size mismatch");
}

/// Handles CPU faults (finds the cause and passes it into a normal Zig panic)
export fn _velox_fault_handler(fault: *Fault) noreturn {
    const cause: []const u8 = switch (fault.cause) {
        .undefined_instruction => "undefined instruction",
        .prefetch_abort => "prefetch abort",
        .data_abort => "data abort",
    };

    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(
        &buf,
        "{s} at pc=0x{x:0>8} lr=0x{x:0>8} sp=0x{x:0>8} cpsr=0x{x:0>8}",
        .{
            cause,
            fault.program_counter,
            fault.link_register,
            fault.stack_pointer,
            fault.cpsr,
        },
    ) catch cause;

    panics.faultPanic(fault, msg);
}
