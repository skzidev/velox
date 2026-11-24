.section .text
.arm
.balign 4
.global _velox_task_switch

_velox_task_switch:
    @ r0 = outgoing ctx
    @ r1 = incoming ctx

    stmia r0!, {r4-r11, lr}
    str sp, [r0]

    ldr sp, [r1, #36]
    ldmia r1!, {r4-r11, lr}

    bx lr

.global _velox_task_trampoline

_velox_task_trampoline:
    @ r0 = user function
    blx r0
    @ b task_exit once task_exit is created
