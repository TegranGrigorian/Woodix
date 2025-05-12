#!/bin/bash
set -e  # Exit on error

echo "=== Simplified Bootloader Test ==="

# 1. Make sure we have directories
mkdir -p esp/EFI/BOOT
mkdir -p esp/EFI/WOODIX

# 2. Create a known working bootloader (copy existing if available)
if [ -f esp/EFI/BOOT/BOOTX64.EFI ]; then
    echo "Using existing bootloader at esp/EFI/BOOT/BOOTX64.EFI"
else
    echo "Copying bootloader from build folder"
    cp src/bootloader/bootx64.efi esp/EFI/BOOT/BOOTX64.EFI || {
        echo "Error: Bootloader not found! Building one..."
        cd src/bootloader && make && cd ../..
        cp src/bootloader/bootx64.efi esp/EFI/BOOT/BOOTX64.EFI
    }
fi

# 3. Create a minimal test kernel that we know should work
echo "Creating test kernel..."
echo -ne '\xB8\x00\x80\x0B\x00\x66\xC7\x00\x4F\x0A\x66\xC7\x40\x02\x4B\x0A\x66\xC7\x40\x04\x21\x0A\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF

# 4. Make sure permissions are correct
chmod +x esp/EFI/BOOT/BOOTX64.EFI
chmod +x esp/EFI/WOODIX/KERNEL.ELF

# 5. Verify file existence and structure
echo "=== Verifying ESP Structure ==="
find esp -type f | sort
echo "Kernel file details:"
ls -la esp/EFI/WOODIX/KERNEL.ELF

# 6. Create startup script that lists directories for debugging
cat > esp/startup.nsh << 'EOL'
@echo -off
echo "=== Directory Listing ==="
ls
echo "=== EFI Directory ==="
ls EFI
echo "=== WOODIX Directory ==="
ls EFI\WOODIX
echo "=== Starting Bootloader ==="
EFI\BOOT\BOOTX64.EFI
EOL
chmod +x esp/startup.nsh

# 7. Run QEMU
echo "=== Running QEMU ==="

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

# Create logs directory
mkdir -p logs

# Run with bare minimum options to avoid potential issues
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 256M \
    -drive format=raw,file=fat:rw:esp \
    -vga std \
    -display gtk \
    -net none \
    -serial file:logs/serial.log

echo "=== Test Complete ==="
