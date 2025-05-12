#![no_std]
#![no_main]

use core::panic::PanicInfo;
mod vga_utils;
mod debug_port;

use vga_utils::vga_colors::Color;
use vga_utils::vga_color_code::ColorCode;
use vga_utils::vga_writter::Writer;
use debug_port::{debug_write_byte, debug_write_str, mark_kernel_stage};

// Kernel stack size (16KB)
const STACK_SIZE: usize = 16 * 1024;

// Kernel stack allocation 
#[repr(align(16))]
struct Stack([u8; STACK_SIZE]);

#[no_mangle]
static STACK: Stack = Stack([0; STACK_SIZE]);

// Entry point - the bootloader will jump here
#[no_mangle]
#[link_section = ".text.start"]
pub unsafe extern "C" fn _start() -> ! {
    // Immediately write to VGA buffer for visual confirmation that we're executing
    let vga_buffer = 0xb8000 as *mut u16;
    *vga_buffer = 0x0F5F;     // "_" in white on black (minimal code that shows we're alive)
    
    // Try to add a delay to allow hardware to stabilize
    for _ in 0..1000000 {
        core::hint::spin_loop();
    }
    
    // Write additional characters for better visibility
    *vga_buffer = 0x0F53;     // "S" in white on black
    *(vga_buffer.add(1)) = 0x0F54; // "T" in white on black
    *(vga_buffer.add(2)) = 0x0F52; // "R" in white on black
    *(vga_buffer.add(3)) = 0x0F54; // "T" in white on black
    *(vga_buffer.add(4)) = 0x0F21; // "!" in white on black
    
    // Try to send debug info
    debug_port::debug_write_str("\nKERNEL: _start reached\n");
    
    // Set up stack and prepare for main kernel code with minimal assembly
    core::arch::asm!(
        // Load stack pointer
        "mov rsp, {stack_ptr}",
        // Clear direction flag (important for memory operations)
        "cld",
        // Clear interrupts for safety
        "cli",
        // Set up a minimal stack frame
        "xor rbp, rbp",
        "push rbp",
        "mov rbp, rsp",
        // Call kernel_main
        "call {kernel_main}",
        // Should never return, but if it does, halt
        "cli",
        "hlt",
        stack_ptr = in(reg) &STACK.0 as *const u8 as usize + STACK_SIZE,
        kernel_main = sym kernel_main,
        options(noreturn)
    );
}

// Our main kernel function that will be called with a proper stack
#[no_mangle]
pub extern "C" fn kernel_main() -> ! {
    // Send a debug message via port 0xE9 (captured by QEMU -debugcon)
    debug_write_str("KERNEL: kernel_main entry point reached\n");
    mark_kernel_stage(1, "Kernel entry point");
    
    // Write to VGA memory directly first to show we're alive
    unsafe {
        let vga_buffer = 0xb8000 as *mut u16;
        *vga_buffer = 0x0F4B; // "K" in white on black
    }
    
    mark_kernel_stage(2, "VGA direct write complete");
    
    // Create a writer with green text on black background
    let mut writer = Writer::new(
        ColorCode::new(
            Color::Green,
            Color::Black,
        )
    );
    
    mark_kernel_stage(3, "VGA Writer initialized");
    
    // Clear the screen and display startup message
    writer.write_string("=================================\n");
    writer.write_string("  Woodix Kernel v0.1.0 Started  \n");
    writer.write_string("=================================\n\n");
    
    // Show basic system info
    writer.write_string("STATUS: Kernel successfully loaded\n");
    writer.write_string("VIDEO: VGA text mode initialized at 0xB8000\n\n");
    
    mark_kernel_stage(4, "VGA initialization complete");
    
    // Demonstrate kernel is running
    for i in 0..5 {
        debug_write_str("KERNEL: Still alive, iteration ");
        debug_write_byte(b'0' + i);
        // debug_write_byte(b'0' + i);
        debug_write_str("\n");
        
        // Simple delay loop
        for _ in 0..10000000 {
            core::hint::spin_loop();
        }
    }
    
    mark_kernel_stage(5, "Entering final idle loop");
    
    // Infinite loop to keep kernel running
    writer.write_string("System halted.");
    
    // Final debug message before loop
    debug_write_str("KERNEL: Entering final loop - kernel execution complete\n");
    
    loop {
        // CPU halt instruction to save power
        #[allow(unused_unsafe)]
        unsafe {
            // Use a no-op instruction that doesn't require inline asm feature
            core::hint::spin_loop();
        }
    }
}

// Panic handler
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    // Send panic info to debug port
    debug_write_str("KERNEL PANIC! System halted.\n");
    
    // Simple panic handling
    let mut error_writer = Writer::new(
        ColorCode::new(
            Color::Red,
            Color::Black,
        )
    );
    
    error_writer.clear_screen();
    error_writer.write_string("================================\n");
    error_writer.write_string("        KERNEL PANIC!          \n");
    error_writer.write_string("================================\n\n");
    error_writer.write_string("The system has encountered a fatal error and cannot continue.\n");
    
    loop {}
}

