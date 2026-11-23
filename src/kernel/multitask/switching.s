.section .text
.arm
.balign 4
.global switchTaskCtx

switchTaskCtx:
    stmia r0!, {r4-r11, lr}
    str sp, r0
    ldr sp, [r1, #32]
    ldmia r1!, {r4-r11, lr}
    bx lr
