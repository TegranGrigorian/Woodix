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
mkdir -p esp/EFI/GRUB
mkdir -p esp/boot/grub

# Move bootloader to ESP
echo "=== Moving Bootloader to ESP ==="
cp src/bootloader/bootx64.efi esp/EFI/Boot/BOOTX64.EFI || { echo "Error: Failed to copy bootloader!"; exit 1; }

# Copy GRUB config
echo "=== Copying GRUB configuration ==="
cp grub/grub.cfg esp/boot/grub/grub.cfg

# Install GRUB EFI bootloader to ESP using grub-mkstandalone
echo "=== Building standalone GRUB EFI binary ==="
grub-mkstandalone \
    -O x86_64-efi \
    --modules="part_gpt part_msdos fat ext2 normal chain boot configfile linux search search_fs_file search_fs_uuid search_label" \
    --locales="" \
    --themes="" \
    -o esp/EFI/GRUB/BOOTX64.EFI \
    "boot/grub/grub.cfg=esp/boot/grub/grub.cfg" \
    || { echo "Error: GRUB mkstandalone failed!"; exit 1; }

# Optionally, copy GRUB EFI binary to standard boot path for removable media
cp esp/EFI/GRUB/BOOTX64.EFI esp/EFI/Boot/BOOTX64.EFI

# Remove duplicate/case-variant EFI boot files to avoid FAT32 case-insensitive conflicts
echo "=== Cleaning up duplicate EFI boot files for FAT32 compatibility ==="
rm -f esp/EFI/Boot/bootx64.efi esp/EFI/Boot/Bootx64.efi

# Create a comprehensive set of kernel files to ensure detection
echo "=== Creating kernel files in all possible locations ==="

# Copy the real kernel ELF to all expected locations
cp target/x86_64-unknown-none/debug/woodix esp/EFI/WOODIX/KERNEL.ELF
cp target/x86_64-unknown-none/debug/woodix esp/EFI/Boot/KERNEL.ELF
cp target/x86_64-unknown-none/debug/woodix esp/KERNEL.ELF
cp target/x86_64-unknown-none/debug/woodix esp/KERNEL

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

# Create a FAT32 disk image for the ESP
echo "=== Creating FAT32 disk image for ESP ==="
rm -f esp.img
mkfs.fat -C esp.img 65536   # 64MB image (65536 * 1KB blocks)

mkdir -p mnt-esp
sudo mount -o loop esp.img mnt-esp

# Use cp -rTn to copy the contents of esp into the mount point, avoiding directory/file conflicts and suppressing warnings
sudo cp -rTn esp mnt-esp
sync
sudo umount mnt-esp
rmdir mnt-esp

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
set -x
echo "QEMU command about to run..."
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 128M \
    -drive if=pflash,format=raw,readonly=on,file=$FIRMWARE \
    -drive format=raw,file=esp.img \
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

set +x

echo "=== Script completed successfully ==="
echo "Debug logs are available in the logs/ directory"
