/* Simple linker script for Multiboot2 compatibility */
OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

SECTIONS
{
    /* Start at 1MB - standard for bootloaders */
    . = 1M;
    
    .multiboot_header : {
        /* Ensure multiboot header is at the beginning */
        KEEP(*(.multiboot_header))
        . = ALIGN(8);
    }
    
    /* Text section on a new page */
    . = ALIGN(4K);
    .text : {
        *(.text.start) /* Entry point first */
        *(.text*)
    }
    
    /* Read-only data on a new page */
    . = ALIGN(4K);
    .rodata : {
        *(.rodata*)
    }
    
    /* Read-write data on a new page */
    . = ALIGN(4K);
    .data : {
        *(.data*)
    }
    
    /* Read-write data (uninitialized) on a new page */
    . = ALIGN(4K);
    .bss : {
        *(.bss*)
        *(COMMON)
    }
    
    /* Move debug sections to a non-conflicting location */
    /* Discard unnecessary sections */
    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
        *(.note*)
    }
}
