ENTRY(__velox_boot__)

MEMORY
{
    USER_RAM (rwx) : ORIGIN = 0x03800000, LENGTH = 0x04800000
}

__stack_size = 128K;
__abort_stack_size = 16K;
__irq_stack_size = 8K;
__fiq_stack_size = 8K;

SECTIONS
{
    . = ORIGIN(USER_RAM);

    .code_signature :
    {
        KEEP(*(.__velox_header__))
        FILL(0)
        . = ORIGIN(USER_RAM) + 0x20;
    } > USER_RAM

    .text : ALIGN(8)
    {
        __text_start = .;
        KEEP(*(.__velox_boot__))
        KEEP(*(.vectors))
        *(.text .text.*)
        __text_end = .;
    } > USER_RAM

    .rodata : ALIGN(8)
    {
        __rodata_start = .;
        *(.rodata .rodata.*)
        __rodata_end = .;
    } > USER_RAM

    .data : ALIGN(8)
    {
        __data_start = .;
        *(.data .data.*)
        __data_end = .;
    } > USER_RAM

    .bss (NOLOAD) : ALIGN(8)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > USER_RAM

    .stack (NOLOAD) : ALIGN(8)
    {
        __stack_bottom = .;
        . += __stack_size;
        __stack_top = .;
    } > USER_RAM

    /* Dedicated stack for the fault handlers. VEXos's own abort stack is too
       small for our fault reporting, and we may need a valid stack even when
       the main stack is corrupt. */
    .abort_stack (NOLOAD) : ALIGN(8)
    {
        __abort_stack_bottom = .;
        . += __abort_stack_size;
        __abort_stack_top = .;
    } > USER_RAM

    /* Dedicated stacks for the IRQ and FIQ handlers. They are banked: the CPU
       switches SP to them automatically when it enters those modes. */
    .irq_stack (NOLOAD) : ALIGN(8)
    {
        __irq_stack_bottom = .;
        . += __irq_stack_size;
        __irq_stack_top = .;
    } > USER_RAM

    .fiq_stack (NOLOAD) : ALIGN(8)
    {
        __fiq_stack_bottom = .;
        . += __fiq_stack_size;
        __fiq_stack_top = .;
    } > USER_RAM

    . = ALIGN(8);
    __heap_start = .;
    __heap_end = ORIGIN(USER_RAM) + LENGTH(USER_RAM);
    __ram_end = ORIGIN(USER_RAM) + LENGTH(USER_RAM);

    /DISCARD/ :
    {
        *(.ARM.exidx)
        *(.ARM.extab*)
        *(.eh_frame*)
    }
}
