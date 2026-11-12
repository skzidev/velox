.syntax unified
.arm
.arch armv7-a

.section .__velox_header__, "a", %progbits
.balign 4

.global __codesig
.type __codesig, %object

__codesig:
    .byte 0x58, 0x56, 0x58, 0x35
    .word 0x00000000
    .word 0x00000002
    .word 0x00000000

    .word 0x00000000
    .word 0x00000000
    .word 0x00000000
    .word 0x00000000

.section .text._velox_boot, "ax", %progbits
.balign 4

.global _velox_boot
.type _velox_boot, %function

_velox_boot:
    mov fp, #0
    ldr sp, =__stack_top

    bl velox_fpu_ensure

    ldr r0, =_bss_start
    ldr r1, =_bss_end
    sub r1, r1, r0

    bl velox_zero_bss

    bl velox_startup

.Lboot_halt:
    b .Lboot_halt

.section .text.velox_fpu_ensure, "ax", %progbits
.type velox_fpu_ensure, %function

velox_fpu_ensure:
    mrc p15, 0, r2, c1, c0, 2
    and r3, r2, #0x00F00000
    cmp r3, #0x00F00000
    beq .Lcpacr_ok

    orr r2, r2, #0x00F00000
    mcr p15, 0, r2, c1, c0, 2
    isb

.Lcpacr_ok:
    vmrs r2, fpexc
    tst r2, #0x40000000
    bne .Lfpu_ok

    orr r2, r2, #0x40000000
    vmsr fpexc, r2
    isb

.Lfpu_ok:
    bx lr

.section .text.velox_zero_bss, "ax", %progbits
.type velox_zero_bss, %function

velox_zero_bss:
    mov r2, #0
    veor q0, q0, q0

.Lzero_loop:
    cmp r1, #16
    blo .Lzero_tail

    vst1.8 {d0-d1}, [r0]!

    subs r1, r1, #16
    b .Lzero_loop

.Lzero_tail:
    cmp r1, #0
    beq .Lzero_done

    strb r2, [r0], #1

    subs r1, r1, #1
    b .Lzero_tail

.Lzero_done:
    bx lr
