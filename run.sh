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

# Use shell to prevent library issues
echo "Running QEMU with minimal environment..."
bash -c "
  unset \$(env | grep -i snap | cut -d= -f1)
  unset LD_LIBRARY_PATH
  unset LD_PRELOAD
  export PATH=/usr/bin:/bin
  /usr/bin/qemu-system-x86_64 \
    -bios \"$FIRMWARE\" \
    -m 128M \
    -drive if=pflash,format=raw,readonly=on,file=\"$FIRMWARE\" \
    -drive format=raw,file=esp.img \
    -vga std \
    -serial file:logs/serial.log \
    -debugcon file:logs/debug.log \
    -no-reboot \
    -no-shutdown \
    -display gtk \
    -monitor stdio \
    -global isa-debugcon.iobase=0xe9
"
