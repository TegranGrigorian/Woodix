#!/usr/bin/env bash
set -e  # Exit on error

echo "=== Fixing Kernel File Placement ==="

# Create all necessary directories with proper case
mkdir -p esp/EFI/BOOT
mkdir -p esp/EFI/WOODIX

# Create a very basic test kernel directly in the WOODIX directory
echo "=== Creating basic test kernel in esp/EFI/WOODIX/KERNEL.ELF ==="
echo -ne '\xB8\x00\x80\x0B\x00\x66\xC7\x00\x4F\x0A\x66\xC7\x40\x02\x4B\x0A\x66\xC7\x40\x04\x21\x0A\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
chmod +x esp/EFI/WOODIX/KERNEL.ELF

echo "=== Verifying kernel file exists ==="
ls -la esp/EFI/WOODIX/KERNEL.ELF

echo "=== Bootloader information ==="
ls -la esp/EFI/BOOT/

echo "=== Creating improved UEFI startup script ==="
cat > esp/startup.nsh << 'EOL'
@echo -off
echo Woodix UEFI Boot Script
echo Checking directory structure...

echo Root directory:
ls

echo EFI directory:
ls EFI

echo EFI/WOODIX directory:
ls EFI\WOODIX

echo Checking kernel file at EFI\WOODIX\KERNEL.ELF:
if exist EFI\WOODIX\KERNEL.ELF then
  echo KERNEL.ELF found - running bootloader...
  EFI\BOOT\BOOTX64.EFI
else
  echo ERROR: Kernel file not found!
  echo Creating kernel file...
  mkdir EFI\WOODIX
  # This is a limitation of the UEFI shell - we can't create binary files directly
  echo Attempting to run bootloader anyway...
  EFI\BOOT\BOOTX64.EFI
endif
EOL

echo "=== CHMOD to ensure executable permissions ==="
chmod +x esp/startup.nsh
chmod +x esp/EFI/BOOT/BOOTX64.EFI
chmod +x esp/EFI/WOODIX/KERNEL.ELF
chmod +x fix_kernel_file.sh

echo "=== Displaying complete ESP structure ==="
find esp -type f | sort
find esp -type d | sort

echo "===== IMPORTANT ====="
echo "Now run: ./bootloader_starter.sh"
echo "=================="
