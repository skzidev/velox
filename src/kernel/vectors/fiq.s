.syntax unified
.arm

.section .text.vectors, "a", %progbits
.balign 4
.global _fiq_handler

_fiq_handler:
    stmdb sp!, {r0-r3, r12, lr}
