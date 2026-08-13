//! IRQ (interrupt request) handler.
//!
//! Pass-through stub for the IRQ exception. The FreeRTOS scheduler tick
//! arrives on this line, so the interrupt must stay in VEXos's hands. The
//! stub saves the AAPCS caller-saved registers plus the FPU state, calls
//! `vexSystemIRQInterrupt` (VEXos's IRQ dispatch) as an ordinary function,
//! restores the state, then returns to the interrupted code with
//! `subs pc, lr, #4` (which also restores CPSR from SPSR_irq).
//!
//! The jumptable slot for `vexSystemIRQInterrupt` holds a *pointer* to the
//! real VEXos dispatch code, not the code itself (Vexide's wrapper functions
//! dereference the slot too). So the stub loads the pointer out of the slot
//! and calls it with `blx`; it must not branch to the slot address directly.
//!
//! This is Vexide's proven handler, adapted to inline the slot dereference
//! instead of calling Vexide's wrapper. It runs in IRQ mode on
//! the IRQ stack, which VEXos set up during boot.

comptime {
    asm (
        \\.section .text.handlers, "ax"
        \\.arm
        \\.align 2

        \\.global irq_handler
        \\irq_handler:
        \\  stmdb sp!, {r0-r3, r12, lr}
        \\  vpush {d0-d7}
        \\  vpush {d16-d31}
        \\  vmrs r1, FPSCR
        \\  push {r1}
        \\  vmrs r1, FPEXC
        \\  push {r1}
        \\  movw r0, #:lower16:vexSystemIRQInterrupt
        \\  movt r0, #:upper16:vexSystemIRQInterrupt
        \\  ldr r0, [r0]
        \\  blx r0
        \\  pop {r1}
        \\  vmsr FPEXC, r1
        \\  pop {r1}
        \\  vmsr FPSCR, r1
        \\  vpop {d16-d31}
        \\  vpop {d0-d7}
        \\  ldmia sp!, {r0-r3, r12, lr}
        \\  subs pc, lr, #4
    );
}
