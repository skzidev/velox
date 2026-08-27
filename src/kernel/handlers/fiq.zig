comptime {
    asm (
        \\.section .text.handlers, "ax"
        \\.arm
        \\.align 2
        \\.global fiq_handler
        \\fiq_handler:
        \\  stmdb sp!, {r0-r3, r12, lr}
        \\  vpush {d0-d7}
        \\  vpush {d16-d31}
        \\  vmrs r1, FPSCR
        \\  push {r1}
        \\  vmrs r1, FPEXC
        \\  push {r1}
        \\  movw r0, #:lower16:vexSystemFIQInterrupt
        \\  movt r0, #:upper16:vexSystemFIQInterrupt
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
