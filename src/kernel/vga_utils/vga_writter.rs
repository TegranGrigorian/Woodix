// VGA screen writer implementation

use core::fmt;
use volatile::Volatile;

use super::vga_color_code::ColorCode;
use super::vga_colors::Color;

// Buffer dimensions
const BUFFER_HEIGHT: usize = 25;
const BUFFER_WIDTH: usize = 80;

// VGA character struct - represents a character in the buffer
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(C)]
struct ScreenChar {
    ascii_character: u8,
    color_code: ColorCode,
}

// VGA buffer struct - represents the text-mode buffer
#[repr(transparent)]
struct Buffer {
    chars: [[Volatile<ScreenChar>; BUFFER_WIDTH]; BUFFER_HEIGHT],
}

// Writer for VGA buffer
pub struct Writer {
    column_position: usize,
    row_position: usize,
    color_code: ColorCode,
}

impl Writer {
    // Create a new Writer with specified color
    pub fn new(color_code: ColorCode) -> Self {
        // Create writer
        let mut writer = Self {
            column_position: 0,
            row_position: 0,
            color_code,
        };
        
        // Clear screen with the new color
        writer.clear_screen();
        
        writer
    }
    
    // Clear screen
    pub fn clear_screen(&mut self) {
        // Direct VGA manipulation for screen clearing
        unsafe {
            let vga_buffer = 0xb8000 as *mut u16;
            for i in 0..BUFFER_HEIGHT * BUFFER_WIDTH {
                // Space character with color attribute
                *vga_buffer.add(i) = 0x20 | (u16::from(self.color_code.0) << 8);
            }
        }
        
        // Reset cursor position
        self.column_position = 0;
        self.row_position = 0;
    }
    
    // Write a single byte
    pub fn write_byte(&mut self, byte: u8) {
        match byte {
            b'\n' => self.new_line(),
            byte => {
                if self.column_position >= BUFFER_WIDTH {
                    self.new_line();
                }
                
                // Get a reference to the VGA buffer
                let vga_buffer = 0xb8000 as *mut u16;
                let index = self.row_position * BUFFER_WIDTH + self.column_position;
                
                unsafe {
                    // Directly write to VGA memory
                    *vga_buffer.add(index) = u16::from(byte) | (u16::from(self.color_code.0) << 8);
                }
                
                self.column_position += 1;
            }
        }
    }
    
    // Write a string
    pub fn write_string(&mut self, s: &str) {
        for byte in s.bytes() {
            match byte {
                // Printable ASCII or newline
                0x20..=0x7e | b'\n' => self.write_byte(byte),
                // Not part of printable ASCII range
                _ => self.write_byte(0xfe), // ■
            }
        }
        
        // Make sure changes are visible by using a memory barrier
        unsafe {
            core::arch::asm!("mfence", options(nomem, nostack));
        }
    }
    
    // Handle newlines
    fn new_line(&mut self) {
        self.column_position = 0;
        
        if self.row_position < BUFFER_HEIGHT - 1 {
            self.row_position += 1;
        } else {
            // Scroll the screen (shift all lines up)
            self.scroll_up();
        }
    }
    
    // Scroll the screen up one line
    fn scroll_up(&mut self) {
        unsafe {
            let vga_buffer = 0xb8000 as *mut u16;
            
            // Move all rows up one line
            for row in 1..BUFFER_HEIGHT {
                for col in 0..BUFFER_WIDTH {
                    let from_index = row * BUFFER_WIDTH + col;
                    let to_index = (row - 1) * BUFFER_WIDTH + col;
                    *vga_buffer.add(to_index) = *vga_buffer.add(from_index);
                }
            }
            
            // Clear the last row
            let last_row = BUFFER_HEIGHT - 1;
            for col in 0..BUFFER_WIDTH {
                let index = last_row * BUFFER_WIDTH + col;
                *vga_buffer.add(index) = 0x20 | (u16::from(self.color_code.0) << 8);
            }
        }
    }
}

// Implement fmt::Write for Writer
impl fmt::Write for Writer {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.write_string(s);
        Ok(())
    }
}

#[allow(dead_code)]
pub fn test() {
    let mut writer = Writer::new(ColorCode::new(Color::Yellow, Color::Black));
    writer.clear_screen();
    writer.write_string("VGA Test: Hello from Woodix Kernel!\n");
    writer.write_string("Line 2: Testing newlines\n");
    writer.write_string("Line 3: Testing colors (should be yellow on black)\n");
    
    // Write a few ASCII characters to demonstrate various printable characters
    writer.write_string("Symbol test: !@#$%^&*()_+{}|:\"<>?~`-=[]\\;',./\n");
    
    // Test tabs
    writer.write_string("Tab\tTest\tTab\tTest\n");
    
    // Fix: Make this mutable
    let mut success_writer = Writer::new(ColorCode::new(Color::Green, Color::Black));
    success_writer.write_string("\nVGA TEST PASSED!");
}