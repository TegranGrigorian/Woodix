OUTPUT_FORMAT("elf64-x86-64")
ENTRY(_start)

SECTIONS {
    /* Kernel starts at 1MB - this is critical! */
    . = 1M;

    /* Ensure 16-byte alignment for the entry point */
    . = ALIGN(16);

    /* The _start function MUST be at the very beginning */
    .text.start : ALIGN(16) {
        *(.text.start)  /* This section will contain _start function */
    }

    /* Regular .text section follows */
    .text : {
        *(.text)
        *(.text.*)
    }

    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Aligned data section */
    . = ALIGN(16);
    .data : {
        *(.data)
        *(.data.*)
    }

    /* Aligned BSS section */
    . = ALIGN(16);
    .bss : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }
    
    /* Export symbols for the entry points so we can verify addresses in debugger */
    __kernel_start = 0x100000;
    __stack_top = ADDR(.bss) + SIZEOF(.bss);
    
    /DISCARD/ : {
        *(.eh_frame_hdr)
        *(.eh_frame)
        *(.note.*)
    }
}
