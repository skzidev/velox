.section .vectors, "ax"
.arm

.align 5
.global _vector_table

_vector_table:
    b reset_entry
    b fault_handler_undef
    b svc_handler
    b fault_handler_pabort
    b fault_handler_dabort
    nop
    b irq_handler
    b fiq_handler
reset_entry:
    movw r0, #:lower16:vexSystemBoot
    movt r0, #:upper16:vexSystemBoot
    ldr r0, [r0]
    bx r0
