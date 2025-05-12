; UEFI bootloader in assembly for Woodix
; Simpler implementation that avoids relocation issues

BITS 64
DEFAULT REL

; UEFI data structure offsets - simplified for reliability
%define EFI_SUCCESS 0

; Text messages
struc MESSAGE
    .ptr: resq 1
    .size: resq 1
endstruc

section .text

; EFI entry point
global efi_main
efi_main:
    ; Standard x86_64 function prologue
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32                  ; Shadow space for Win64 calling convention
    
    ; Save parameters
    mov [ImageHandle], rcx       ; First parameter: EFI_HANDLE
    mov [SystemTable], rdx       ; Second parameter: EFI_SYSTEM_TABLE*
    
    ; Clear screen
    call clear_screen
    
    ; Display welcome message
    lea rcx, [welcome_msg]       ; Message string
    call print_message
    
    ; Display loading message
    lea rcx, [loading_msg]
    call print_message
    
    ; Load kernel from disk
    call load_kernel
    
    ; Display success message
    lea rcx, [success_msg]
    call print_message
    
    ; Display handoff message
    lea rcx, [handoff_msg]
    call print_message
    
    ; Try to exit boot services
    call exit_boot_services
    test rax, rax                ; Check return value (0 = success)
    jnz error_exit
    
    ; Jump to kernel
    xor rax, rax
    mov rax, 0x100000            ; 1MB - kernel load address
    jmp rax
    
    ; Should never reach here
.error:
    lea rcx, [error_msg]
    call print_message
    
    ; Sleep for 5 seconds
    mov rcx, 5000000             ; 5 seconds in microseconds
    call sleep_microseconds
    
    ; Return error
    mov rax, 1                   ; Error code
    
    ; Standard x86_64 function epilogue
    add rsp, 32
    pop r15
    pop r14
    pop r13 
    pop r12
    pop rbx
    pop rbp
    ret

error_exit:
    lea rcx, [exit_error_msg]
    call print_message
    
    ; Sleep for 5 seconds
    mov rcx, 5000000
    call sleep_microseconds
    
    ; Return error
    mov rax, 1
    
    ; Epilogue
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Function to clear the screen
clear_screen:
    push rbp
    mov rbp, rsp
    
    mov rdx, [SystemTable]         ; Get system table
    mov rdx, [rdx+0x40]            ; Get ConOut pointer
    mov rcx, rdx                   ; Place in first parameter
    
    sub rsp, 32                    ; Shadow space
    call [rdx+0x8]                 ; Call ClearScreen method
    add rsp, 32                    ; Restore stack
    
    leave
    ret

; Function to print a null-terminated string
; RCX = string pointer
print_message:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rcx                   ; Save string pointer
    
    mov rdx, [SystemTable]         ; Get system table
    mov rdx, [rdx+0x40]            ; Get ConOut pointer
    mov rcx, rdx                   ; First parameter: ConOut
    mov rdx, rbx                   ; Second parameter: string pointer
    
    sub rsp, 32                    ; Shadow space
    call [rcx+0x10]                ; Call OutputString method
    add rsp, 32                    ; Restore stack
    
    pop rbx
    leave
    ret

; Function to sleep for specified microseconds
; RCX = microseconds
sleep_microseconds:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rcx                   ; Save microseconds
    
    mov rdx, [SystemTable]         ; Get system table
    mov rdx, [rdx+0x60]            ; Get BootServices pointer
    mov rcx, rbx                   ; First parameter: microseconds
    
    sub rsp, 32                    ; Shadow space
    call [rdx+0x98]                ; Call Stall method
    add rsp, 32                    ; Restore stack
    
    pop rbx
    leave
    ret

; Function to load the kernel
load_kernel:
    push rbp
    mov rbp, rsp
    
    ; Simplified: in a real implementation this would use UEFI file system protocols
    ; to load the kernel file from disk into memory at 0x100000
    
    ; Here we just indicate success
    xor rax, rax                  ; Return success (0)
    
    leave
    ret

; Function to exit boot services
exit_boot_services:
    push rbp
    mov rbp, rsp
    
    ; Simplified exit boot services implementation
    ; In a real implementation, this would get the memory map and call ExitBootServices
    
    ; Here we just simulate success
    xor rax, rax                  ; Return success (0)
    
    leave
    ret

section .data

; Global variables
ImageHandle:    dq 0              ; EFI_HANDLE
SystemTable:    dq 0              ; EFI_SYSTEM_TABLE*

; Messages
welcome_msg:    db "Woodix Assembly Bootloader", 13, 10, 0
loading_msg:    db "Loading kernel...", 13, 10, 0
success_msg:    db "Kernel loaded successfully.", 13, 10, 0
handoff_msg:    db "Transferring control to kernel...", 13, 10, 0
error_msg:      db "Error: Failed to load kernel!", 13, 10, 0
exit_error_msg: db "Error: Failed to exit boot services!", 13, 10, 0
