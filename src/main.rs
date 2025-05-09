#![no_std]
#![no_main]
#![feature(abi_efiapi)]

use core::panic::PanicInfo;

#[unsafe(no_mangle)]
pub extern "efiapi" fn efi_main() -> ! {
    // Entry point for the UEFI application
    loop {}
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}