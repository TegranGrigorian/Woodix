; Ultra-simple kernel for Woodix - guaranteed to work on any x86_64 setup
BITS 64

; Make sure there's a recognizable signature at the start of the file
; so the bootloader can confirm it loaded a valid kernel
db 'WDXKRNL', 0  ; 8-byte signature

start:
    ; First, clear interrupts for safety
    cli
    
    ; Write "OK!" to VGA memory
    mov eax, 0xB8000           ; Standard VGA text buffer address
    
    mov word [eax], 0x0A4F     ; 'O' in green on black (0x0A = green)
    mov word [eax+2], 0x0A4B   ; 'K' in green on black
    mov word [eax+4], 0x0A21   ; '!' in green on black
    
    ; Now halt the CPU
forever:
    hlt                       ; Halt instruction - stops CPU until interrupt
    jmp forever               ; Jump back to halt in case of non-maskable interrupt
