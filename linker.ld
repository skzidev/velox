/* Zeolite linker script */

ENTRY(__zeolite_boot__)

MEMORY
{
    USER_RAM (rwx) : ORIGIN = 0x03800000, LENGTH = 0x04800000
}

__stack_size = 128K;

SECTIONS
{
    . = ORIGIN(USER_RAM);

    .code_signature :
    {
        KEEP(*(.__zeolite_header__))
        FILL(0)
        . = ORIGIN(USER_RAM) + 0x20;
    } > USER_RAM

    .text : ALIGN(8)
    {
        __text_start = .;
        KEEP(*(.__zeolite_boot__))
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
