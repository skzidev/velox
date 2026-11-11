.syntax unified
.arm

.section .text.vectors, "ax", %progbits
.balign 4

_undefined_fault_handler:
    dsb
    movw sp, #:lower16:__abort_stack_top
    movt sp, #:upper16:__abort_stack_top
