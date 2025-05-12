#!/usr/bin/env bash

# Exit on any error
set -e

PROJECT_ROOT="$(pwd)"
echo "=== Woodix Bootloader Build Script ==="

# Navigate to bootloader directory
echo "=== Navigating to bootloader directory ==="
cd src/bootloader || { echo "Error: Bootloader directory not found!"; exit 1; }

# Build bootloader
echo "=== Building UEFI bootloader ==="
make || { echo "Error: Build failed!"; exit 1; }

# Return to project root
cd "$PROJECT_ROOT" || { echo "Error: Could not return to project root!"; exit 1; }

# Create necessary directories
echo "=== Creating directory structure ==="
mkdir -p esp/EFI/Boot
mkdir -p esp/EFI/WOODIX

# Move bootloader to ESP
echo "=== Moving Bootloader to ESP ==="
cp src/bootloader/bootx64.efi esp/EFI/Boot/ || { echo "Error: Failed to copy bootloader!"; exit 1; }

# Check if we already have a kernel file
if [ ! -f esp/EFI/WOODIX/KERNEL.ELF ]; then
    echo "=== No kernel found, creating one with create_basic_kernel.sh ==="
    ./create_basic_kernel.sh || { echo "Error: Failed to create kernel!"; exit 1; }
fi

echo "=== File listing for verification ==="
find esp -type f | sort

# Run QEMU with better debugging options
echo "=== Running Bootloader in QEMU ==="
if [ -f /usr/share/ovmf/OVMF.fd ]; then
    FIRMWARE="/usr/share/ovmf/OVMF.fd"
elif [ -f /usr/share/edk2/ovmf/OVMF_CODE.fd ]; then
    FIRMWARE="/usr/share/edk2/ovmf/OVMF_CODE.fd"
else
    echo "Error: OVMF UEFI firmware not found! Please install OVMF package."
    exit 1
fi

echo "=== Building Kernel ==="
./build_kernel.sh

# Run with VGA display and debug options - fix the serial port conflict
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 128M \
    -drive format=raw,file=fat:rw:esp \
    -vga std \
    -serial file:serial.log \
    -d int,cpu_reset,guest_errors,page \
    -display gtk \
    -monitor tcp:127.0.0.1:55555,server,nowait

echo "=== Script completed successfully ==="
