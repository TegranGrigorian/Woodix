@echo -off
echo "=== Directory Listing ==="
ls
echo "=== EFI Directory ==="
ls EFI
echo "=== WOODIX Directory ==="
ls EFI\WOODIX
echo "=== Starting Bootloader ==="
EFI\BOOT\BOOTX64.EFI
