ENTRY(_velox_boot)

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
    .header ORIGIN(USER_RAM) :
    {
        KEEP(*(.__velox_header__))
    } > USER_RAM
    .text : ALIGN(8)
    {
        __text_start = .;

        KEEP(*(.text._velox_boot))
        KEEP(*(.vectors))

        *(.text .text.*)

        __text_end = .;
    } > USER_RAM

    .rodata : ALIGN(8)
    {
        _rodata_start = .;
        *(.rodata .rodata.*)
        _rodata_end = .;
    } > USER_RAM

    .data : ALIGN(8)
    {
        _data_start = .;
        *(.data .data.*);
        _data_end = .;
    }

    .bss (NOLOAD) : ALIGN(8)
    {
        _bss_start = .;
        *(.bss .bss.*);
        *(COMMON);
        _bss_end = .;
    } > USER_RAM

    .stack (NOLOAD) : ALIGN(8)
    {
        __stack_bottom = .;
        . += __stack_size;
        __stack_top = .;
    } > USER_RAM

    .abort_stack (NOLOAD) : ALIGN(8)
    {
        __abort_stack_bottom = .;
        . += __abort_stack_size;
        __abort_stack_top = .;
    } > USER_RAM

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
}

ASSERT(SIZEOF(.header) == 32, "Header must be exactly 32 bytes");

. = ALIGN(8);
__heap_start = .;
__heap_end = ORIGIN(USER_RAM) + LENGTH(USER_RAM);
__ram_end = ORIGIN(USER_RAM) + LENGTH(USER_RAM);
