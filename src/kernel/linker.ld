OUTPUT_FORMAT("elf64-x86-64")
ENTRY(_start)

SECTIONS {
    /* Kernel starts at 1MB */
    . = 1M;

    .text : {
        *(.text .text.*)
    }

    .rodata : {
        *(.rodata .rodata.*)
    }

    .data : {
        *(.data .data.*)
    }

    .bss : {
        *(.bss .bss.*)
        *(COMMON)
    }
}
