#![no_std]
#![no_main]

use core::fmt::Write;
use core::panic::PanicInfo;
use uefi::prelude::*;
use uefi::proto::console::text::Output;

#[entry]
pub extern "efiapi" fn efi_main(handle: Handle, mut system_table: SystemTable<Boot>) -> Status {
    // Initialize UEFI services
    uefi_services::init(&mut system_table).unwrap_or_default();
    
    // Clear the screen
    let stdout = system_table.stdout();
    stdout.clear().unwrap_or_default();
    
    // Display a message
    writeln!(stdout, "Hello from Woodix OS!").unwrap_or_default();
    writeln!(stdout, "UEFI application started successfully.").unwrap_or_default();
    
    // Wait for a key press before exiting
    system_table.boot_services().stall(10_000_000); // Stall for 10 seconds
    
    Status::SUCCESS
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}