#!/bin/bash


#remember to run qemu-system-x86_64 -drive format=raw,file=fat:rw:esp -bios /usr/share/ovmf/OVMF.fd
#for it to work :)
set -e

echo "Setting up the UEFI application development environment..."

# Update and install required packages
echo "Installing required packages..."
sudo apt update
sudo apt install -y build-essential qemu-system-x86 ovmf rustc cargo

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
if [ -f "/usr/share/ovmf/OVMF.fd" ]; then
    OVMF_PATH="/usr/share/ovmf/OVMF.fd"
elif [ -f "/usr/share/OVMF/OVMF_CODE_4M.fd" ]; then
    OVMF_PATH="/usr/share/OVMF/OVMF_CODE_4M.fd" 
elif [ -f "/usr/share/qemu/OVMF.fd" ]; then
    OVMF_PATH="/usr/share/qemu/OVMF.fd"
else
    OVMF_PATH=$(find /usr/share -name "*OVMF*.fd" | head -n 1)
fi
# Run the application in QEMU
echo "Running the UEFI application in QEMU..."
echo "This might not work, if it doesnt use the run.sh script"
sleep 2
qemu-system-x86_64 -drive format=raw,file=fat:rw:esp -bios "$OVMF_PATH"

echo "setting permissions for the run.sh script"
chmod +x run.sh

echo "Setup complete!"
