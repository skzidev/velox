//! Vector table installation.
//!
//! The VEX V5 brain uses a Cortex-A9, which dispatches CPU exceptions through a
//! vector table located at the address held in the VBAR coprocessor register.
//! By default that table belongs to VEXos. Installing our own gives Velox its
//! own entry points:
//!   * reset -> VEXos boot (`vexSystemBoot`)
//!   * undefined instruction / prefetch abort / data abort -> Velox's fault
//!     handlers in handlers/fault.zig
//!   * SVC -> handlers/svc.zig (passes through to VEXos's syscall dispatch)
//!   * IRQ / FIQ -> handlers/irq.zig and handlers/fiq.zig (pass through to
//!     VEXos's FreeRTOS scheduler tick / fast handlers)
//!
//! The IRQ/FIQ/SVC handlers are Vexide-style stubs: they save the registers
//! and FPU state, call the VEXos handler (`vexSystem*Interrupt`) as an
//! ordinary function, then restore the state and perform the exception return
//! themselves. VEXos's FreeRTOS scheduler therefore keeps running its tick and
//! context switches exactly as it does for a normal Vexide program. The fault
//! handlers stay in Velox, since those are always fatal for a user program.
//!
//! Each vector-table entry is a plain ARM branch. The IRQ/FIQ/SVC handlers
//! hand control to VEXos by loading the *pointer* stored in the jumptable
//! slot for the corresponding `vexSystem*Interrupt` symbol (see
//! handlers/irq.zig, handlers/fiq.zig, handlers/svc.zig). The reset vector
//! does the same for `vexSystemBoot`, so a CPU reset hands control back to
//! VEXos's boot code.

comptime {
    // Vector table definition.
    // See Table B1-3 of the ARMv7-A instruction manual (page B1-1170).
    // Each entry is a single ARM instruction, so the table is 8 entries of
    // 4 bytes each. The whole table must be 32-byte aligned (`.align 5`).
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

extern var vector_table: u8;

/// Point VBAR at our vector table so CPU exceptions dispatch to our handlers.
pub fn install_vectors() void {
    // Make sure the vector table contents are visible before they can be used.
    asm volatile ("dsb" ::: .{ .memory = true });

    const vbar_addr: u32 = @intFromPtr(&vector_table);
    asm volatile (
        "mcr p15, 0, %[addr], c12, c0, 0"
        :
        : [addr] "r" (vbar_addr),
        : .{ .memory = true }
    );
    // Make sure the new exception vectors are visible before they can be used.
    asm volatile ("isb" ::: .{ .memory = true });
}
