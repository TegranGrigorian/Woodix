// VGA color code implementation

use super::vga_colors::Color;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(transparent)]
pub struct ColorCode(pub u8);  // Make the field public

impl ColorCode {
    pub fn new(foreground: Color, background: Color) -> ColorCode {
        ColorCode((background as u8) << 4 | (foreground as u8))
    }
    
    #[allow(dead_code)]
    pub fn as_u8(&self) -> u8 {
        self.0
    }
}