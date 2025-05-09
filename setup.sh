#!/bin/bash

set -e

echo "Setting up the UEFI application development environment..."

# Update and install required packages
echo "Installing required packages..."
sudo apt update
sudo apt install -y build-essential qemu ovmf rustc cargo

# Install Rust nightly toolchain
echo "Installing Rust nightly toolchain..."
rustup install nightly
rustup default nightly

# Add the UEFI target
echo "Adding the x86_64-unknown-uefi target..."
rustup target add x86_64-unknown-uefi

# Install the Rust source component
echo "Installing Rust source component..."
rustup component add rust-src

# Create the ESP directory structure
echo "Creating the ESP directory structure..."
mkdir -p esp/EFI/Boot

# Add a .cargo/config.toml file to simplify build commands
echo "Configuring Cargo for UEFI builds..."
mkdir -p .cargo
cat > .cargo/config.toml <<EOF
[unstable]
build-std = ["core", "compiler_builtins"]
build-std-features = ["compiler-builtins-mem"]

[build]
target = "x86_64-unknown-uefi"
EOF

# Build the project
echo "Building the UEFI application..."
cargo +nightly build -Z build-std=core,compiler_builtins --target x86_64-unknown-uefi

# Copy the built EFI file to the ESP directory
echo "Copying the built EFI file to the ESP directory..."
cp target/x86_64-unknown-uefi/debug/Woodix.efi esp/EFI/Boot/Bootx64.efi

# Verify OVMF installation
echo "Verifying OVMF installation..."
OVMF_PATH=$(find /usr/share -name "OVMF_CODE.fd" | head -n 1)
if [ -z "$OVMF_PATH" ]; then
    echo "Error: OVMF_CODE.fd not found. Ensure the 'ovmf' package is installed."
    exit 1
fi
echo "OVMF firmware found at: $OVMF_PATH"

# Run the application in QEMU
echo "Running the UEFI application in QEMU..."
qemu-system-x86_64 -drive format=raw,file=fat:rw:esp -bios "$OVMF_PATH"

echo "Setup complete!"
