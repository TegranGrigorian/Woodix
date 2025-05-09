ENTRY(_start);

SECTIONS {
    . = 0x00100000; /* Kernel entry point address */

    .text : {
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    .bss : {
        *(.bss*)
        *(COMMON)
    }
}
