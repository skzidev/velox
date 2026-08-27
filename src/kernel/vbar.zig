comptime {
    asm (
        \\.section .vectors, "ax"
        \\.arm
        \\.align 5
        \\.global vector_table
        \\vector_table:
        \\  b reset_entry              @ reset: hand control to VEXos boot
        \\  b fault_handler_undef      @ undefined instruction
        \\  b svc_handler              @ supervisor call
        \\  b fault_handler_pabort     @ prefetch abort
        \\  b fault_handler_dabort     @ data abort
        \\  nop                        @ reserved
        \\  b irq_handler              @ interrupt request
        \\  b fiq_handler              @ fast interrupt request
        \\reset_entry:
        \\  movw r0, #:lower16:vexSystemBoot
        \\  movt r0, #:upper16:vexSystemBoot
        \\  ldr r0, [r0]
        \\  bx r0
    );
}

extern var vector_table: u8;

pub fn install_vectors() void {
    asm volatile ("dsb" ::: .{ .memory = true });

    const vbar_addr: u32 = @intFromPtr(&vector_table);
    asm volatile ("mcr p15, 0, %[addr], c12, c0, 0"
        :
        : [addr] "r" (vbar_addr),
        : .{ .memory = true });
    asm volatile ("isb" ::: .{ .memory = true });
}
