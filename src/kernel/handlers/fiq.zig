//! # FIQ (Fast Interrupt Request) Handler
//!
//! Handles fast hardware interrupts. Identical in structure to the IRQ
//! handler but dispatches to the VEXos `vexSystemFIQInterrupt` handler.
//! FIQs have the highest priority and are used for time-critical
//! hardware events.

comptime {
    asm (
        \\.section .text.handlers, "ax"
        \\.arm
        \\.align 2
        \\.global fiq_handler
        \\fiq_handler:
        \\  stmdb sp!, {r0-r3, r12, lr}   @ save caller-saved registers
        \\  vpush {d0-d7}                  @ save NEON low registers
        \\  vpush {d16-d31}                @ save NEON high registers
        \\  vmrs r1, FPSCR                 @ save FP status register
        \\  push {r1}
        \\  vmrs r1, FPEXC                 @ save FP exception register
        \\  push {r1}
        \\  movw r0, #:lower16:vexSystemFIQInterrupt  @ load VEXos handler
        \\  movt r0, #:upper16:vexSystemFIQInterrupt
        \\  ldr r0, [r0]
        \\  blx r0                         @ call VEXos FIQ handler
        \\  pop {r1}                       @ restore FPEXC
        \\  vmsr FPEXC, r1
        \\  pop {r1}                       @ restore FPSCR
        \\  vmsr FPSCR, r1
        \\  vpop {d16-d31}                 @ restore NEON high registers
        \\  vpop {d0-d7}                   @ restore NEON low registers
        \\  ldmia sp!, {r0-r3, r12, lr}   @ restore caller-saved registers
        \\  subs pc, lr, #4               @ return from interrupt
    );
}
