#!/usr/bin/env bash
set -e  # Exit on error

echo "=== Fixing Woodix Bootloader Structure ==="

# Create proper UEFI boot directory structure
mkdir -p esp/EFI/BOOT
mkdir -p esp/EFI/WOODIX

# If we have a bootloader, make sure it's in the fallback path with the proper name
if [ -f src/bootloader/bootx64.efi ]; then
    echo "Found bootloader, copying to fallback path..."
    cp src/bootloader/bootx64.efi esp/EFI/BOOT/BOOTX64.EFI  # Note: uppercase name
else
    echo "Building bootloader..."
    cd src/bootloader
    make clean
    make
    cd ../..
    cp src/bootloader/bootx64.efi esp/EFI/BOOT/BOOTX64.EFI  # Note: uppercase name
fi

# Create a simple test kernel
echo "Creating simple test kernel..."
echo -ne '\xB8\x00\x80\x0B\x00\x66\xC7\x00\x4F\x0A\x66\xC7\x40\x02\x4B\x0A\x66\xC7\x40\x04\x21\x0A\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
chmod +x esp/EFI/WOODIX/KERNEL.ELF

# Create startup.nsh script that UEFI shell will execute automatically
echo "Creating UEFI startup script..."
echo -e "fs0:\ncd EFI\\BOOT\nBOOTX64.EFI" > esp/startup.nsh
chmod +x esp/startup.nsh

echo "=== ESP directory structure ==="
find esp -type f | sort

echo "=== Running QEMU with fixed structure ==="
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

# Create logs directory
mkdir -p logs

# Run QEMU with proper UEFI options
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 256M \
    -drive format=raw,file=fat:rw:esp \
    -net none \
    -vga std \
    -serial file:logs/serial.log \
    -debugcon file:logs/debug.log \
    -global isa-debugcon.iobase=0xe9 \
    -no-reboot \
    -display gtk \
    -monitor stdio

echo "=== Complete ==="
