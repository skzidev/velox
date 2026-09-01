//! # Vector Base Address Register (VBAR)
//!
//! Defines the ARM exception vector table and installs it into the
//! VBAR (CP15 c12). The vector table contains 8 entries, each
//! corresponding to an ARM exception type:
//!
//! | Offset | Exception | Handler |
//! |--------|-----------|---------|
//! | 0x00 | Reset | `vexSystemBoot` (VEXos) |
//! | 0x04 | Undefined Instruction | `fault_handler_undef` |
//! | 0x08 | SVC (Supervisor Call) | `svc_handler` |
//! | 0x0C | Prefetch Abort | `fault_handler_pabort` |
//! | 0x10 | Data Abort | `fault_handler_dabort` |
//! | 0x14 | Reserved | NOP |
//! | 0x18 | IRQ | `irq_handler` |
//! | 0x1C | FIQ | `fiq_handler` |
//!
//! The table is placed in the `.vectors` section and must be 32-byte
//! aligned.

comptime {
    asm (
        \\.section .vectors, "ax"
        \\.arm
        \\.align 5
        \\.global vector_table
        \\vector_table:
        \\  b reset_entry              @ reset: hand control to VEXos boot
        \\  b fault_handler_undef      @ undefined instruction
        \\  b svc_handler              @ supervisor call
        \\  b fault_handler_pabort     @ prefetch abort
        \\  b fault_handler_dabort     @ data abort
        \\  nop                        @ reserved
        \\  b irq_handler              @ interrupt request
        \\  b fiq_handler              @ fast interrupt request
        \\reset_entry:
        \\  movw r0, #:lower16:vexSystemBoot
        \\  movt r0, #:upper16:vexSystemBoot
        \\  ldr r0, [r0]
        \\  bx r0
    );
}

/// Reference to the vector table in the `.vectors` section.
extern var vector_table: u8;

/// Installs the exception vector table by writing the address of
/// [`vector_table`] into the ARM VBAR register (CP15 c12).
///
/// Performs a `dsb` before and an `isb` after the `mcr` to ensure
/// the memory barrier is respected and the instruction pipeline is
/// flushed.
pub fn install_vectors() void {
    asm volatile ("dsb" ::: .{ .memory = true });

    const vbar_addr: u32 = @intFromPtr(&vector_table);
    asm volatile ("mcr p15, 0, %[addr], c12, c0, 0"
        :
        : [addr] "r" (vbar_addr),
        : .{ .memory = true });
    asm volatile ("isb" ::: .{ .memory = true });
}
