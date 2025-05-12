#![no_std]
#![no_main]

use core::panic::PanicInfo;
mod vga_utils;

use vga_utils::vga_colors::Color;
use vga_utils::vga_color_code::ColorCode;
use vga_utils::vga_writter::Writer;

// Entry point
#[no_mangle]
pub extern "C" fn _start() -> ! {
    // Initialize stack pointer to avoid stack overflows
    unsafe {
        // Write to VGA memory directly first to show we're alive
        let vga_buffer = 0xb8000 as *mut u16;
        *vga_buffer = 0x0F4B; // "K" in white on black
    }
    
    // Create a writer with green text on black background
    let mut writer = Writer::new(
        ColorCode::new(
            Color::Green,
            Color::Black,
        )
    );
    
    // Clear the screen and display startup message
    writer.write_string("=================================\n");
    writer.write_string("  Woodix Kernel v0.1.0 Started  \n");
    writer.write_string("=================================\n\n");
    
    // Show basic system info
    writer.write_string("STATUS: Kernel successfully loaded\n");
    writer.write_string("VIDEO: VGA text mode initialized at 0xB8000\n\n");
    
    // Infinite loop to keep kernel running
    writer.write_string("System halted.");
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

