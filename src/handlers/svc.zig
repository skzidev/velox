//! SVC (supervisor call) handler.
//!
//! Pass-through stub for the SVC exception. SVC instructions are how the
//! FreeRTOS port on VEXos requests a context switch (e.g. `portYIELD`), so
//! the exception must stay in VEXos's hands.
//!
//! The stub saves the AAPCS caller-saved registers, extracts the SVC
//! immediate from the faulting instruction (checking the T-bit in SPSR to
//! know whether the interrupted code was in ARM or Thumb mode), calls
//! `vexSystemSWInterrupt` as an ordinary function, restores the saved SPSR
//! and registers, then returns with `ldmia sp!, {r0-r3, r12, pc}^`, which
//! copies SPSR_svc back into CPSR.
//!
//! The jumptable slot for `vexSystemSWInterrupt` holds a *pointer* to the
//! real VEXos SVC dispatch code, not the code itself (Vexide's wrapper
//! functions dereference the slot too). So the stub loads the pointer out of
//! the slot and calls it with `blx` (keeping the extracted SVC immediate in
//! r0 as the argument); it must not branch to the slot address directly.
//!
//! This is Vexide's proven handler, adapted to inline the slot dereference
//! instead of calling Vexide's wrapper.

comptime {
    asm (
        \\.section .text.handlers, "ax"
        \\.arm
        \\.align 2

        \\.global svc_handler
        \\svc_handler:
        \\  push {r0-r3, r12, lr}
        \\  mrs r0, spsr
        \\  push {r0, r3}
        \\  tst r0, #0x20
        \\  ldrhne r0, [lr, #-2]
        \\  bicne r0, r0, #0xff00
        \\  ldreq r0, [lr, #-4]
        \\  biceq r0, r0, #0xff000000
        \\  movw r1, #:lower16:vexSystemSWInterrupt
        \\  movt r1, #:upper16:vexSystemSWInterrupt
        \\  ldr r1, [r1]
        \\  blx r1
        \\  pop {r0, r3}
        \\  msr spsr_cxsf, r0
        \\  ldmia sp!, {r0-r3, r12, pc}^
    );
}
