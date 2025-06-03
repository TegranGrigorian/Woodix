#!/bin/bash
mkdir -p logs

# Find OVMF firmware
if [ -f /usr/share/ovmf/OVMF.fd ]; then
    FIRMWARE="/usr/share/ovmf/OVMF.fd"
elif [ -f /usr/share/edk2/ovmf/OVMF_CODE.fd ]; then
    FIRMWARE="/usr/share/edk2/ovmf/OVMF_CODE.fd"
else
    echo "Error: OVMF UEFI firmware not found!"
    exit 1
fi

echo "Running QEMU via Flatpak..."
flatpak run --filesystem=host org.qemu.QEMU.x86_64 \
  -machine q35 \
  -bios "$FIRMWARE" \
  -m 128M \
  -vga std \
  -serial file:$(pwd)/logs/serial.log \
  -debugcon file:$(pwd)/logs/debug.log \
  -no-reboot \
  -no-shutdown \
  -display gtk \
  -monitor stdio
