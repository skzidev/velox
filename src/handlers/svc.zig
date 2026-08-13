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
