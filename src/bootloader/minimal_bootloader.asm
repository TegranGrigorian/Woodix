; Minimal UEFI bootloader that works with strict UEFI implementations
; This avoids many potential compatibility issues

BITS 64
DEFAULT REL

; EFI standard defines
%define EFI_SUCCESS                     0
%define EFI_ERROR                       0x8000000000000000
%define EFI_LOAD_ERROR                  0x8000000000000001
%define EFI_BUFFER_TOO_SMALL            0x8000000000000005

section .text

; EFI entry point - this matches the prototype for UEFI
global efi_main
efi_main:
    ; Entry point parameters: RCX=ImageHandle, RDX=SystemTable
    push rbp
    mov rbp, rsp
    sub rsp, 64                  ; Reserve shadow space for function calls
    
    ; Save parameters
    mov [ImageHandle], rcx
    mov [SystemTable], rdx
    
    ; Get console output pointer from system table (offset 0x40)
    mov rax, rdx
    mov rax, [rax+0x40]          ; Get ConOut pointer
    mov [ConOut], rax
    
    ; Clear screen
    mov rcx, [ConOut]            ; First parameter: ConOut pointer
    mov rax, [rcx]               ; Get function table
    call [rax+8]                 ; Call ClearScreen method (offset 8)
    
    ; Print "Woodix Bootloader"
    mov rcx, [ConOut]            ; First parameter: ConOut pointer 
    lea rdx, [WelcomeMsg]        ; Second parameter: string pointer
    mov rax, [rcx]               ; Get function table
    call [rax+16]                ; Call OutputString method (offset 16)
    
    ; Print "Loading kernel..."
    mov rcx, [ConOut]            ; First parameter: ConOut pointer
    lea rdx, [LoadingMsg]        ; Second parameter: string pointer 
    mov rax, [rcx]               ; Get function table
    call [rax+16]                ; Call OutputString method
    
    ; In a complete bootloader, we would:
    ; 1. Load the kernel from disk
    ; 2. Set up memory mappings
    ; 3. Exit boot services
    ; 4. Jump to the kernel
    
    ; For this minimal test, show a success message
    mov rcx, [ConOut]            ; First parameter: ConOut pointer
    lea rdx, [SuccessMsg]        ; Second parameter: string pointer
    mov rax, [rcx]
    call [rax+16]                ; Call OutputString method
    
    ; Stall for a bit to see the message
    mov rax, [SystemTable]
    mov rax, [rax+0x60]          ; Get BootServices pointer
    mov rcx, 5000000             ; 5 seconds (in microseconds)
    call [rax+0x98]              ; Call Stall method (offset 0x98)
    
    ; Return success
    xor rax, rax                 ; EFI_SUCCESS = 0
    
    ; Standard epilogue
    leave
    ret

section .data
    ImageHandle:    dq 0
    SystemTable:    dq 0
    ConOut:         dq 0
    
    WelcomeMsg:     db "Woodix Bootloader", 13, 10, 13, 10, 0
    LoadingMsg:     db "Loading kernel...", 13, 10, 0
    SuccessMsg:     db "Bootloader ran successfully!", 13, 10, 0
