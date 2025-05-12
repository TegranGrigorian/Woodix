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
make clean
make || { echo "Error: Build failed!"; exit 1; }

# Return to project root
cd "$PROJECT_ROOT" || { echo "Error: Could not return to project root!"; exit 1; }

# Create necessary directories
echo "=== Creating directory structure ==="
mkdir -p esp/EFI/Boot
mkdir -p esp/EFI/WOODIX

# Move bootloader to ESP
echo "=== Moving Bootloader to ESP ==="
cp src/bootloader/bootx64.efi esp/EFI/Boot/BOOTX64.EFI || { echo "Error: Failed to copy bootloader!"; exit 1; }

# Create a comprehensive set of kernel files to ensure detection
echo "=== Creating kernel files in all possible locations ==="

# Create a minimal kernel directly in binary form
KERNEL_CODE='\xB8\x00\x80\x0B\x00\x66\xC7\x00\x4F\x0A\x66\xC7\x40\x02\x4B\x0A\x66\xC7\x40\x04\x21\x0A\xFA\xF4\xEB\xFE'

# Write to multiple locations to ensure one works
echo -ne $KERNEL_CODE > esp/EFI/WOODIX/KERNEL.ELF
echo -ne $KERNEL_CODE > esp/EFI/Boot/KERNEL.ELF  
echo -ne $KERNEL_CODE > esp/KERNEL.ELF
echo -ne $KERNEL_CODE > esp/KERNEL

# Set proper permissions
chmod +x esp/EFI/WOODIX/KERNEL.ELF 
chmod +x esp/EFI/Boot/KERNEL.ELF
chmod +x esp/KERNEL.ELF
chmod +x esp/KERNEL

# Create a startup.nsh script to help debug
cat > esp/startup.nsh << 'EOF'
@echo -off
echo Woodix Boot Debug
echo \EFI
ls \EFI
echo \EFI\WOODIX  
ls \EFI\WOODIX
echo \EFI\Boot
ls \EFI\Boot
echo Root:
ls \
echo Loading bootloader manually...
\EFI\Boot\BOOTX64.EFI
EOF

chmod +x esp/startup.nsh

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

# Create a log directory if it doesn't exist
mkdir -p logs

# Run with enhanced debugging options to verify bootloader-to-kernel handoff
echo "=== Running Bootloader in QEMU with enhanced debugging ==="
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 128M \
    -drive format=raw,file=fat:rw:esp \
    -vga std \
    -serial file:logs/serial.log \
    -debugcon file:logs/debug.log \
    -d int,cpu_reset,guest_errors,page,in_asm \
    -D logs/qemu_trace.log \
    -no-reboot \
    -no-shutdown \
    -display gtk \
    -monitor stdio \
    -global isa-debugcon.iobase=0xe9

echo "=== Script completed successfully ==="
echo "Debug logs are available in the logs/ directory"
