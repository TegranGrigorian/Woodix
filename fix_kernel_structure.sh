#!/usr/bin/env bash
set -e

echo "=== Fixing Kernel File Structure ==="

# Create proper directory structure
mkdir -p esp/EFI/BOOT
mkdir -p esp/EFI/WOODIX

# Check if bootloader exists
if [ ! -f esp/EFI/BOOT/BOOTX64.EFI ]; then
    echo "Bootloader not found, copying from src..."
    cp src/bootloader/bootx64.efi esp/EFI/BOOT/BOOTX64.EFI || {
        echo "Error: No bootloader found to copy. Building one..."
        cd src/bootloader
        make clean
        make
        cd ../..
        cp src/bootloader/bootx64.efi esp/EFI/BOOT/BOOTX64.EFI
    }
fi

# Create a minimal test kernel
echo "Creating minimal test kernel..."
echo -ne '\xB8\x00\x80\x0B\x00\x66\xC7\x00\x4F\x0A\x66\xC7\x40\x02\x4B\x0A\x66\xC7\x40\x04\x21\x0A\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
chmod +x esp/EFI/WOODIX/KERNEL.ELF

# Create a better startup.nsh script
echo "Creating improved startup script..."
cat > esp/startup.nsh << 'EOL'
@echo -off
echo Woodix UEFI Boot Script
echo Listing ESP root contents:
ls
echo 
echo Listing EFI directory:
ls EFI
echo
echo Listing EFI/WOODIX directory:
ls EFI\WOODIX
echo
echo Checking kernel file:
if exist EFI\WOODIX\KERNEL.ELF then
  echo Kernel file found!
else
  echo ERROR: Kernel file not found!
endif
echo
echo Launching bootloader...
EFI\BOOT\BOOTX64.EFI
EOL
chmod +x esp/startup.nsh

echo "=== Listing File Structure ==="
find esp -type f | sort
ls -la esp/EFI/WOODIX/

echo "Run bootloader with: ./bootloader_starter.sh"
chmod +x bootloader_starter.sh fix_kernel_structure.sh
echo "=== Fix Complete ==="
