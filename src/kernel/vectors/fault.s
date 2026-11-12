.section .text.handlers, "ax"
.arm
.align 2
.global fault_handler_undef
fault_handler_undef:
    dsb
    movw sp, #:lower16:__abort_stack_top
    movt sp, #:upper16:__abort_stack_top
    push {r0-r12}
    mov r0, #0
    mrs r1, spsr
    tst r1, #0x20
    subeq lr, #4
    subne lr, #2
    b fault_common
.global fault_handler_pabort
fault_handler_pabort:
    dsb
    movw sp, #:lower16:__abort_stack_top
    movt sp, #:upper16:__abort_stack_top
    push {r0-r12}
    mov r0, #1
    mrs r1, spsr
    sub lr, #4
    b fault_common
.global fault_handler_dabort
fault_handler_dabort:
    dsb
    movw sp, #:lower16:__abort_stack_top
    movt sp, #:upper16:__abort_stack_top
    push {r0-r12}
    mov r0, #2
    mrs r1, spsr
    sub lr, #8
    b fault_common
fault_common:
    push {r0, r1, lr}
    stmdb sp, {sp}^
    sub sp, sp, #4
    stmdb sp, {lr}^
    sub sp, sp, #4
    mov r0, sp
    bl _velox_fault_handler
    b .
