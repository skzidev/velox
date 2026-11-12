const std = @import("std");
const jmptbl = @import("jumptable");

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

export fn _velox_fault_handler(fault: *Fault) noreturn {
    const cause: []const u8 = switch (fault.cause) {
        .undefined_instruction => "undefined instruction",
        .prefetch_abort => "prefetch abort",
        .data_abort => "data abort",
    };

    _ = cause;

    jmptbl.vexSystemExitRequest();
    while (true) {
        asm volatile ("nop");
    }
}
