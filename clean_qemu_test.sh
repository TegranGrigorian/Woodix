#!/bin/bash
# Set up clean environment variables
unset $(env | grep -i snap | cut -d= -f1)
unset LD_LIBRARY_PATH
unset LD_PRELOAD

# Run QEMU with minimal options
echo "Testing QEMU with clean environment..."
/usr/bin/qemu-system-x86_64 --version
