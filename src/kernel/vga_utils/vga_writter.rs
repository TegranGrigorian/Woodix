// VGA screen writer implementation

use core::fmt;
use super::vga_color_code::ColorCode;
use super::vga_colors::Color;
use super::text_code::{ScreenChar, Buffer, VGA_BUFFER_HEIGHT, VGA_BUFFER_WIDTH};

pub struct Writer {
    column_position: usize,
    row_position: usize,
    color_code: ColorCode,
    #[allow(dead_code)]
    buffer: &'static mut Buffer,
}

impl Writer {
    pub fn new(color_code: ColorCode) -> Writer {
        // Create and initialize the writer
        let mut writer = Writer {
            column_position: 0,
            row_position: 0,
            color_code,
            buffer: unsafe { &mut *(0xb8000 as *mut Buffer) },
        };
        
        // Clear the screen on initialization
        writer.clear_screen();
        
        writer
    }

    pub fn clear_screen(&mut self) {
        let blank = ScreenChar {
            ascii_character: b' ',
            color_code: self.color_code,
        };

        for row in 0..VGA_BUFFER_HEIGHT {
            for col in 0..VGA_BUFFER_WIDTH {
                unsafe {
                    // We need to use raw pointer operations because Buffer doesn't implement Volatile correctly
                    let buffer_ptr = 0xb8000 as *mut u16;
                    let offset = row * VGA_BUFFER_WIDTH + col;
                    let char_value = (self.color_code.0 as u16) << 8 | (blank.ascii_character as u16);
                    
                    // Write the character to video memory
                    buffer_ptr.add(offset).write_volatile(char_value);
                }
            }
        }
        
        // Reset cursor position
        self.column_position = 0;
        self.row_position = 0;
    }

    pub fn write_byte(&mut self, byte: u8) {
        match byte {
            b'\n' => self.new_line(),
            b'\r' => self.column_position = 0,
            b'\t' => {
                // Handle tab by inserting spaces (4 spaces per tab)
                for _ in 0..4 {
                    if self.column_position < VGA_BUFFER_WIDTH {
                        self.write_byte(b' ');
                    }
                }
            },
            b'\x08' => {
                // Backspace - move back one character if possible
                if self.column_position > 0 {
                    self.column_position -= 1;
                    self.write_byte(b' ');
                    self.column_position -= 1;
                }
            },
            _ => {
                if self.column_position >= VGA_BUFFER_WIDTH {
                    self.new_line();
                }

                let row = self.row_position;
                let col = self.column_position;

                let color_code = self.color_code;
                let char_value = ScreenChar {
                    ascii_character: byte,
                    color_code,
                };

                // We need to use raw pointer operations to ensure volatile writes
                unsafe {
                    let buffer_ptr = 0xb8000 as *mut u16;
                    let offset = row * VGA_BUFFER_WIDTH + col;
                    let value = (char_value.color_code.0 as u16) << 8 | (char_value.ascii_character as u16);
                    
                    // Write the character to video memory
                    buffer_ptr.add(offset).write_volatile(value);
                }

                self.column_position += 1;
            }
        }
    }

    pub fn write_string(&mut self, s: &str) {
        for byte in s.bytes() {
            match byte {
                // printable ASCII byte or newline
                0x20..=0x7e | b'\n' | b'\r' | b'\t' | b'\x08' => self.write_byte(byte),
                // not part of printable ASCII range
                _ => self.write_byte(0xfe),
            }
        }
    }

    fn new_line(&mut self) {
        if self.row_position < VGA_BUFFER_HEIGHT - 1 {
            // If we're not at the bottom, just move down
            self.row_position += 1;
        } else {
            // Need to scroll the screen up
            for row in 1..VGA_BUFFER_HEIGHT {
                for col in 0..VGA_BUFFER_WIDTH {
                    unsafe {
                        let buffer_ptr = 0xb8000 as *mut u16;
                        let src_offset = row * VGA_BUFFER_WIDTH + col;
                        let dst_offset = (row - 1) * VGA_BUFFER_WIDTH + col;
                        
                        let char_value = buffer_ptr.add(src_offset).read_volatile();
                        buffer_ptr.add(dst_offset).write_volatile(char_value);
                    }
                }
            }
            
            // Clear the bottom row
            self.clear_row(VGA_BUFFER_HEIGHT - 1);
        }
        
        self.column_position = 0;
    }

    fn clear_row(&mut self, row: usize) {
        let blank = ScreenChar {
            ascii_character: b' ',
            color_code: self.color_code,
        };
        
        for col in 0..VGA_BUFFER_WIDTH {
            unsafe {
                let buffer_ptr = 0xb8000 as *mut u16;
                let offset = row * VGA_BUFFER_WIDTH + col;
                let char_value = (blank.color_code.0 as u16) << 8 | (blank.ascii_character as u16);
                
                // Write the character to video memory
                buffer_ptr.add(offset).write_volatile(char_value);
            }
        }
    }
}

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