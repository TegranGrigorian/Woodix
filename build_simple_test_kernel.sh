#!/bin/bash

# Create a very simple test kernel
mkdir -p esp/EFI/WOODIX

# Create this extremely simple 64-bit kernel that just writes "OK" to the screen
cat > simple.asm << 'EOL'
BITS 64
start:
    ; Write "OK" to VGA memory
    mov rax, 0xB8000      ; VGA text buffer address
    mov word [rax], 0x0F4F ; "O" with white on black attribute
    mov word [rax+2], 0x0F4B ; "K" with white on black attribute
    
    ; Loop forever
    cli                   ; Disable interrupts
loop:
    hlt                   ; Halt the CPU
    jmp loop              ; Loop forever
EOL

# Assemble the kernel if nasm is available
if command -v nasm &> /dev/null; then
    echo "Assembling simple test kernel..."
    nasm -f bin simple.asm -o esp/EFI/WOODIX/KERNEL.ELF
    rm simple.asm
    echo "Test kernel created at esp/EFI/WOODIX/KERNEL.ELF"
else
    echo "NASM not found. Creating test kernel with direct binary..."
    # Simplified binary code that writes "OK" to screen
    echo -ne '\xB8\x00\x80\x0B\x00\x00\x00\x00\x66\xC7\x00\x4F\x0F\x66\xC7\x40\x02\x4B\x0F\xFA\xF4\xEB\xFD' > esp/EFI/WOODIX/KERNEL.ELF
    echo "Test kernel created at esp/EFI/WOODIX/KERNEL.ELF"
fi
