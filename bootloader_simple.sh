#!/usr/bin/env bash

# Exit on any error
set -e

PROJECT_ROOT="$(pwd)"
echo "=== Woodix Bootloader Simple Script ==="

# Just run QEMU with the ESP directory
echo "=== Running Bootloader in QEMU (Simple Version) ==="
if [ -f /usr/share/ovmf/OVMF.fd ]; then
    FIRMWARE="/usr/share/ovmf/OVMF.fd"
elif [ -f /usr/share/edk2/ovmf/OVMF_CODE.fd ]; then
    FIRMWARE="/usr/share/edk2/ovmf/OVMF_CODE.fd"
else
    echo "Error: OVMF UEFI firmware not found! Please install OVMF package."
    exit 1
fi

# Basic QEMU command - no sound, no extra options
qemu-system-x86_64 \
    -bios "$FIRMWARE" \
    -m 128M \
    -drive format=raw,file=fat:rw:esp \
    -vga std

echo "=== Script completed successfully ==="
