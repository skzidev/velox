//! # SVC (Supervisor Call) Handler
//!
//! Handles software interrupt (SVC) exceptions. Extracts the SVC
//! immediate from the instruction that triggered the exception
//! (supporting both ARM and Thumb encodings) and dispatches to the
//! VEXos `vexSystemSWInterrupt` handler. The SPSR is saved and
//! restored so that the interrupted program resumes correctly.

comptime {
    asm (
        \\.section .text.handlers, "ax"
        \\.arm
        \\.align 2
        \\.global svc_handler
        \\svc_handler:
        \\  push {r0-r3, r12, lr}       @ save caller-saved registers
        \\  mrs r0, spsr                 @ read saved program status
        \\  push {r0, r3}                @ save SPSR and r3
        \\  tst r0, #0x20                @ test Thumb bit (bit 5)
        \\  ldrhne r0, [lr, #-2]        @ Thumb: extract SVC number from halfword
        \\  bicne r0, r0, #0xff00       @ clear upper byte
        \\  ldreq r0, [lr, #-4]         @ ARM: extract SVC number from word
        \\  biceq r0, r0, #0xff000000   @ clear upper byte
        \\  movw r1, #:lower16:vexSystemSWInterrupt  @ load VEXos handler
        \\  movt r1, #:upper16:vexSystemSWInterrupt
        \\  ldr r1, [r1]
        \\  blx r1                       @ call VEXos SVC handler
        \\  pop {r0, r3}                 @ restore SPSR and r3
        \\  msr spsr_cxsf, r0           @ write back saved program status
        \\  ldmia sp!, {r0-r3, r12, pc}^ @ restore registers and return
    );
}
