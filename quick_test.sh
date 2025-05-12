#!/usr/bin/env bash
set -e

echo "=== Quick Test for Bootloader ==="
echo "This script creates a simple test kernel to verify bootloader operation"

# Create directory structure
mkdir -p esp/EFI/WOODIX
mkdir -p esp/EFI/Boot

# Check if the bootloader binary exists
if [ ! -f esp/EFI/Boot/bootx64.efi ]; then
    echo "Bootloader not found, attempting to build it..."
    # Navigate to bootloader directory
    cd src/bootloader || { echo "Error: Bootloader directory not found!"; exit 1; }
    # Build bootloader
    make || { echo "Error: Build failed!"; exit 1; }
    # Return to project root
    cd - > /dev/null
    # Move bootloader to ESP
    cp src/bootloader/bootx64.efi esp/EFI/Boot/ || { echo "Error: Failed to copy bootloader!"; exit 1; }
fi

# Create a very simple test kernel
echo "Creating simple test kernel..."

# This is a simpler test kernel that might work better with UEFI:
# 1. Starts with a jump instruction to skip a small header
# 2. Has a clear marker at the beginning (16 bytes)  
# 3. Makes writes to VGA memory in a tight loop
echo -ne '\xEB\x10WOODIXKERNELTEST\xB8\x00\x80\x0B\x00\xC6\x00\x4F\xC6\x40\x01\x0F\xC6\x40\x02\x4B\xC6\x40\x03\x0F\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
chmod +x esp/EFI/WOODIX/KERNEL.ELF

echo "Test kernel created!"

# Create logs directory
mkdir -p logs

echo "Running QEMU with UEFI and debugging..."

# Find UEFI firmware
if [ -f /usr/share/ovmf/OVMF.fd ]; then
    FIRMWARE="/usr/share/ovmf/OVMF.fd"
elif [ -f /usr/share/edk2/ovmf/OVMF_CODE.fd ]; then
    FIRMWARE="/usr/share/edk2/ovmf/OVMF_CODE.fd"
elif [ -f /usr/share/qemu/OVMF.fd ]; then
    FIRMWARE="/usr/share/qemu/OVMF.fd"
else
    echo "Error: OVMF UEFI firmware not found! Please install OVMF package."
    exit 1
fi

# Run QEMU with enhanced debugging options
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 128M \
    -drive format=raw,file=fat:rw:esp \
    -vga std \
    -serial file:logs/serial.log \
    -debugcon file:logs/debug.log \
    -global isa-debugcon.iobase=0xe9 \
    -d int,cpu_reset \
    -D logs/log.txt \
    -no-reboot \
    -display gtk \
    -monitor stdio

echo "Test completed!"
echo "Check logs/serial.log and logs/debug.log for output"
echo "Also examine logs/log.txt for QEMU debug information"
