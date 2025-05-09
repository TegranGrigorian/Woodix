#!/bin/bash

#build, copy and run the UEFI application

cargo +nightly build -Z build-std=core,compiler_builtins --target x86_64-unknown-uefi

#copy
cp target/x86_64-unknown-uefi/debug/Woodix.efi esp/EFI/Boot/Bootx64.efi

#run
qemu-system-x86_64 -drive format=raw,file=fat:rw:esp -bios /usr/share/ovmf/OVMF.fd