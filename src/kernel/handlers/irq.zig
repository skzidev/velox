//! # IRQ (Interrupt Request) Handler
//!
//! Handles standard hardware interrupts. Saves all caller-saved
//! registers and NEON/FP state before dispatching to the VEXos
//! `vexSystemIRQInterrupt` handler, then restores state and returns
//! from the interrupt.

comptime {
    asm (
        \\.section .text.handlers, "ax"
        \\.arm
        \\.align 2
        \\.global irq_handler
        \\irq_handler:
        \\  stmdb sp!, {r0-r3, r12, lr}   @ save caller-saved registers
        \\  vpush {d0-d7}                  @ save NEON low registers
        \\  vpush {d16-d31}                @ save NEON high registers
        \\  vmrs r1, FPSCR                 @ save FP status register
        \\  push {r1}
        \\  vmrs r1, FPEXC                 @ save FP exception register
        \\  push {r1}
        \\  movw r0, #:lower16:vexSystemIRQInterrupt  @ load VEXos handler
        \\  movt r0, #:upper16:vexSystemIRQInterrupt
        \\  ldr r0, [r0]
        \\  blx r0                         @ call VEXos IRQ handler
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
