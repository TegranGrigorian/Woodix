#![no_std]
#![no_main]

use uefi::prelude::*;
use core::fmt::Write;
#[entry]
fn efi_main(handle: Handle, mut system_table: SystemTable<Boot>) -> Status {
    // Initialize UEFI services
    uefi_services::init(&mut system_table).unwrap_or_default();
    
    // Clear the screen
    let stdout = system_table.stdout();
    stdout.clear().unwrap_or_default();
    
    // Display a message
    writeln!(stdout, "Your mom").unwrap_or_default();
    writeln!(stdout, "Woodix").unwrap_or_default();
    
    // Wait for a key press before exiting
    system_table.boot_services().stall(10_000_000); // Stall for 10 seconds
    
    Status::SUCCESS
}