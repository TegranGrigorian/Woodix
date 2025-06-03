#![no_std]
#![no_main]

// NOTE: If you encounter the error:
// qemu-system-x86_64: symbol lookup error: /snap/core20/current/lib/x86_64-linux-gnu/libpthread.so.0: undefined symbol: __libc_pthread_init, version GLIBC_PRIVATE
// This is a QEMU snap package issue, not a problem with the kernel code.
// Solution: Use a native QEMU installation instead of the snap version:
//   1. sudo apt remove --purge qemu-system-x86 (if using snap)
//   2. sudo apt install qemu-system-x86
//   3. Or run: flatpak install flathub org.qemu.QEMU

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

// Multiboot2 header
// Must be 8-byte aligned, fixed format
#[repr(C, align(8))]
struct MultibootHeader {
    magic: u32,
    architecture: u32,
    header_length: u32,
    checksum: u32,
}

// Using u32 array to ensure proper memory layout
#[link_section = ".multiboot_header"]
#[no_mangle]
pub static MULTIBOOT2_HEADER: [u32; 23] = [
    // Multiboot2 header (8 bytes)
    0xE85250D6,                      // magic
    0,                               // architecture (i386)
    23 * 4,                          // header length in bytes (92 bytes)
    0xFFFFFFFF - (0xE85250D6 + 0 + (23 * 4)) + 1, // checksum
    
    // Framebuffer tag (type 5)
    5, 0,                            // type 5, flags 0
    20,                              // size
    80, 25, 0,                       // width, height, depth (text mode)
    
    // Module alignment tag (type 6)
    6, 0,                            // type 6, flags 0
    8,                               // size
    
    // Information request tag (type 1)
    1, 0,                            // type 1, flags 0
    16,                              // size
    1, 3, 6, 10,                     // requesting tags: memory map and more
    
    // End tag
    0, 0,                            // type 0, flags 0
    8                                // size
];

//MONKEY TIMEEE!EE!!E!E!E!
#[no_mangle]
#[link_section = ".text.start"]
pub unsafe extern "C" fn _start() -> ! {
    // Test VGA memory directly with a very simple pattern
    let vga_buffer = 0xb8000 as *mut u16;
    
    // Clear the screen with spaces
    for i in 0..80*25 {
        *vga_buffer.add(i) = 0x0720; // White on black space
    }
    
    // Write a recognizable test pattern - a border of asterisks
    for col in 0..80 {
        // Top and bottom borders
        *vga_buffer.add(col) = 0x4F2A;                // '*' white on red
        *vga_buffer.add(24 * 80 + col) = 0x4F2A;      // '*' white on red
    }
    
    for row in 0..25 {
        // Left and right borders
        *vga_buffer.add(row * 80) = 0x4F2A;           // '*' white on red
        *vga_buffer.add(row * 80 + 79) = 0x4F2A;      // '*' white on red
    }
    
    // Write a test message in the center with high visibility
    let msg = b"[WOODIX OS BOOTING]";
    let row = 12;
    let col_start = 40 - msg.len() / 2;
    for (i, &byte) in msg.iter().enumerate() {
        *vga_buffer.add(row * 80 + col_start + i) = 0x2F00 | byte as u16; // Green on white
    }
    
    // Debug port message
    debug_port::debug_write_str("\nKERNEL: _start reached\n");
    
    // Wait a bit to see the display
    for _ in 0..10000000 {
        core::hint::spin_loop();
    }
    
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
    // Try another direct VGA test to rule out boot issues
    unsafe {
        let vga_buffer = 0xb8000 as *mut u16;
        
        // Write "KERNEL" in center with high contrast
        let msg = b"KERNEL MAIN";
        let row = 5;
        let col_start = 40 - msg.len() / 2;
        for (i, &byte) in msg.iter().enumerate() {
            *vga_buffer.add(row * 80 + col_start + i) = 0x5F00 | byte as u16; // White on magenta
        }
    }
    
    // Debug message
    debug_write_str("KERNEL: kernel_main reached\n");
    
    // Wait again to see if this display persists
    for _ in 0..10000000 {
        core::hint::spin_loop();
    }
    
    // Now try the VGA writer
    let mut writer = Writer::new(
        ColorCode::new(
            Color::Yellow,
            Color::Blue, // High contrast
        )
    );
    
    // Clear and write the welcome message
    writer.clear_screen();
    
    // Test each row of the display with distinct content
    for row in 0..10 {
        for _ in 0..row {
            writer.write_byte(b' '); // Indent
        }
        writer.write_string("Row ");
        // Convert row number to string manually
        let digit = b'0' + row as u8;
        writer.write_byte(digit);
        writer.write_string(": WOODIX OS TEST LINE\n");
    }
    
    // ...existing code...
    loop {}
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

