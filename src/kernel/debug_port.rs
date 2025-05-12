//! Debug port utilities for kernel diagnostics
//! Uses QEMU's debug port (0xe9) which can be captured with the -debugcon option

/// Write a single byte to the debug port
pub fn debug_write_byte(byte: u8) {
    unsafe {
        core::arch::asm!("out 0xe9, al", in("al") byte);
    }
}

/// Write a string to the debug port
pub fn debug_write_str(s: &str) {
    for byte in s.bytes() {
        debug_write_byte(byte);
    }
}

#[allow(dead_code)]
/// Write a numerical value as hex to debug port
pub fn debug_write_hex(value: u64) {
    let hex_chars = b"0123456789ABCDEF";
    debug_write_str("0x");
    
    // Print 16 hex digits (for u64)
    for i in (0..16).rev() {
        let nibble = ((value >> (i * 4)) & 0xF) as usize;
        debug_write_byte(hex_chars[nibble]);
    }
}

/// Write a marker indicating kernel stage
pub fn mark_kernel_stage(stage: u8, message: &str) {
    debug_write_str("\n[KERNEL-STAGE-");
    debug_write_byte(b'0' + stage);
    debug_write_str("] ");
    debug_write_str(message);
    debug_write_str("\n");
}
