#!/usr/bin/env bash
set -e  # Exit on error

echo "=== Building Woodix with Assembly Bootloader ==="

# Create logs directory
mkdir -p logs

# Build the assembly bootloader
echo "=== Building assembly bootloader ==="
cd src/bootloader || { echo "Error: Bootloader directory not found!"; exit 1; }
make -f Makefile.asm clean
make -f Makefile.asm
cd ../..

# Prepare ESP directory with proper case-sensitive paths
echo "=== Preparing ESP directory structure ==="
mkdir -p esp/EFI/BOOT
mkdir -p esp/EFI/WOODIX  # UPPERCASE is important

# Copy bootloader to ESP - IMPORTANT: Use uppercase for EFI files
echo "=== Copying bootloader to ESP ==="
cp src/bootloader/bootx64.efi esp/EFI/BOOT/BOOTX64.EFI  # UPPERCASE is important

# Create a test kernel - THIS IS CRITICAL
echo "=== Creating test kernel ==="

# Create the kernel file directly in the WOODIX directory
echo -ne '\xB8\x00\x80\x0B\x00\x66\xC7\x00\x4F\x0A\x66\xC7\x40\x02\x4B\x0A\x66\xC7\x40\x04\x21\x0A\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
chmod +x esp/EFI/WOODIX/KERNEL.ELF
echo "Basic kernel created successfully at esp/EFI/WOODIX/KERNEL.ELF"

# Create an explicit list of files command
echo "=== ESP Directory Structure ==="
find esp -type f | sort
ls -la esp/EFI/WOODIX/

# Create UEFI startup script
echo "Creating UEFI startup script..."
echo -e "fs0:\nls\ncd EFI\\BOOT\nls\nBOOTX64.EFI" > esp/startup.nsh
chmod +x esp/startup.nsh

# Run QEMU
echo "=== Starting QEMU ==="
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

echo "=== Running in QEMU ==="
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 256M \
    -drive format=raw,file=fat:rw:esp \
    -net none \
    -vga std \
    -no-reboot \
    -serial file:logs/serial.log \
    -debugcon file:logs/debug.log \
    -global isa-debugcon.iobase=0xe9 \
    -display gtk \
    -monitor stdio

echo "=== Complete ==="
