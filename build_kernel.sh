#!/usr/bin/env bash
set -e  # Exit on error

echo "=== Woodix Kernel Build Script ==="

# Clean previous build
if [ "$1" = "clean" ]; then
    echo "=== Cleaning previous builds ==="
    cargo clean
    rm -rf target
    echo "=== Clean completed ==="
    exit 0
fi

# Handle the nightly toolchain issue
echo "=== Building kernel ==="
# Check if rustup is installed
if command -v rustup &> /dev/null; then
    echo "Using rustup to invoke cargo with nightly toolchain..."
    # Use rustup to run cargo with nightly toolchain
    rustup run nightly cargo build -Z build-std=core,compiler_builtins --target x86_64-unknown-none
else
    # Fall back to trying cargo directly (assuming nightly is the default)
    echo "Rustup not found, trying direct cargo command..."
    cargo build -Z build-std=core,compiler_builtins --target x86_64-unknown-none || {
        echo "Error: Failed to build with direct cargo command."
        echo "Please install rustup or ensure the nightly toolchain is set as default."
        echo "You can install rustup with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    }
fi

# Analyze the output binary
echo "=== Finding kernel binary ==="
# Look in the debug directory with the correct target
KERNEL_DIR="target/x86_64-unknown-none/debug"
KERNEL_BIN=""

# Check for multiple possible filenames
if [ -f "$KERNEL_DIR/woodix" ]; then
    KERNEL_BIN="$KERNEL_DIR/woodix"
elif [ -f "$KERNEL_DIR/libwoodix.a" ]; then
    KERNEL_BIN="$KERNEL_DIR/libwoodix.a"
else
    # If not found, search for any executable files
    KERNEL_BIN=$(find "$KERNEL_DIR" -type f -executable -not -path "*/\.*" | grep -v '\.d$' | head -1)
    
    # If still not found, try searching the entire target directory
    if [ -z "$KERNEL_BIN" ]; then
        echo "Searching all of target directory..."
        KERNEL_BIN=$(find target -type f -not -path "*/\.*" -not -path "*/deps/*" \
                     \( -name "woodix*" -o -name "libwoodix*" \) \
                     -not -name "*.d" -not -name "*.rmeta" \
                     | head -1)
    fi
fi

if [ -z "$KERNEL_BIN" ]; then
    echo "❌ ERROR: Could not find any suitable kernel binary!"
    echo "Available files in target directory:"
    find target -type f -not -path "*/\.*" -not -name "*.d" -not -name "*.rmeta" | grep -v "deps" | sort
    
    echo -e "\nThis could be caused by a build error or incorrect crate configuration."
    echo "Checking for build artifacts that might be useful:"
    find target -name "woodix*" -type f | sort
    exit 1
fi

echo "✅ Kernel binary found at: $KERNEL_BIN"
echo "=== Binary details: ==="
file "$KERNEL_BIN" || echo "File command not available"

# Check ELF header
echo -e "\n=== ELF Header: ==="
readelf -h "$KERNEL_BIN" || echo "Warning: readelf not available"

# Create a simple assembly kernel for testing
if [ "$1" = "raw" ]; then
    echo "=== Creating raw assembly kernel for testing ==="
    mkdir -p esp/EFI/WOODIX
    
    # Create a series of test kernels that write to different memory addresses
    cat > test_kernel.asm << 'EOL'
; Basic kernel test - writing at multiple possible VGA memory addresses
BITS 64

; Entry point - just jump to the main code
start:
    ; Test VGA standard address (0xB8000)
    mov eax, 0xB8000
    mov byte [eax], 'A'     ; 'A' at offset 0
    mov byte [eax+1], 0x0F  ; White on black
    
    ; Try alternative memory addresses in case memory mapping is different
    
    ; Try alternative 1: 1MB + VGA address
    mov eax, 0x100000 + 0xB8000
    mov byte [eax], 'B'     ; 'B' at 1MB+VGA offset
    mov byte [eax+1], 0x0E  ; Yellow on black
    
    ; Try alternative 2: Direct VGA at higher half
    mov eax, 0xC00B8000
    mov byte [eax], 'C'     ; 'C' at higher-half mapping
    mov byte [eax+1], 0x0D  ; Magenta on black
    
    ; Try writing to fixed memory offsets
    ; If UEFI maps memory differently, at least one of these might be visible
    mov eax, 0x1000         ; 4KB offset
    mov byte [eax], 'D'
    mov byte [eax+1], 0x0C  ; Red
    
    mov eax, 0x10000        ; 64KB offset
    mov byte [eax], 'E'  
    mov byte [eax+1], 0x0B  ; Cyan
    
    mov eax, 0x200000       ; 2MB offset
    mov byte [eax], 'F'
    mov byte [eax+1], 0x0A  ; Green
    
    ; Safe infinite loop
loop_forever:
    jmp loop_forever
EOL

    # Assemble if nasm is available
    if command -v nasm > /dev/null; then
        echo "Assembling test kernel..."
        nasm -f bin -o esp/EFI/WOODIX/KERNEL.ELF test_kernel.asm
        
        # Create a simple but different alternate test binary
        cat > test_kernel2.asm << 'EOL'
; Ultra-simplified kernel
BITS 16                      ; Try 16-bit real mode
org 0                        ; Assume we're loaded at offset 0

start:
    ; Write directly to VGA memory using real-mode segment addressing
    mov ax, 0xB800           ; VGA segment
    mov es, ax               ; Set ES to VGA segment
    
    ; Write 'OK' in white on black
    mov byte [es:0], 'O'     ; Character
    mov byte [es:1], 0x0F    ; Attribute (white on black)
    mov byte [es:2], 'K'     ; Character
    mov byte [es:3], 0x0F    ; Attribute (white on black)
    
    ; Loop forever
    jmp $
EOL
        nasm -f bin -o esp/EFI/WOODIX/KERNEL_ALT.ELF test_kernel2.asm
        
        echo "✅ Test kernels created:"
        echo "   - esp/EFI/WOODIX/KERNEL.ELF (64-bit, multi-address test)"
        echo "   - esp/EFI/WOODIX/KERNEL_ALT.ELF (16-bit real mode test)"
        
        # Create a bootloader configuration file
        cat > esp/EFI/BOOT/boot.cfg << 'EOL'
# Woodix Boot Configuration
kernel_path=\EFI\WOODIX\KERNEL.ELF
# alternate=\EFI\WOODIX\KERNEL_ALT.ELF
EOL
        
        # Clean up
        rm test_kernel.asm test_kernel2.asm
    else
        # Create a simpler assembly file with better compatibility
        cat > test_kernel.asm << 'EOL'
; Ultra basic flat binary kernel
BITS 64

; Code starts here - keep it extremely simple
start:
    ; Use only basic instructions
    mov eax, 0xB8000    ; VGA buffer address
    
    ; Write "OK" in bright white on black (0x0F attribute)
    mov byte [eax], 'O'
    mov byte [eax+1], 0x0F
    mov byte [eax+2], 'K'
    mov byte [eax+3], 0x0F
    
.halt:
    ; Simple infinite loop
    jmp .halt
EOL

        # Assemble if nasm is available
        if command -v nasm > /dev/null; then
            echo "Assembling with NASM..."
            nasm -f bin -o esp/EFI/WOODIX/KERNEL.ELF test_kernel.asm
            
            # Verify the file was created successfully
            if [ -f esp/EFI/WOODIX/KERNEL.ELF ]; then
                echo "✅ Raw kernel successfully created"
                ls -la esp/EFI/WOODIX/KERNEL.ELF
            else
                echo "❌ Failed to create kernel file"
                exit 1
            fi
            
            # Clean up
            rm test_kernel.asm
        else
            # Create a basic binary manually if nasm isn't available
            echo "NASM not found, creating basic binary manually..."
            # Machine code for:
            # mov eax, 0xB8000
            # mov byte [eax], 'O'
            # mov byte [eax+1], 0x0F
            # mov byte [eax+2], 'K'
            # mov byte [eax+3], 0x0F
            # jmp $
            echo -ne '\xB8\x00\x80\x0B\x00\xC6\x00\x4F\xC6\x40\x01\x0F\xC6\x40\x02\x4B\xC6\x40\x03\x0F\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
            chmod +x esp/EFI/WOODIX/KERNEL.ELF
            echo "✅ Basic binary kernel created"
        fi
    fi
    
    echo "Running bootloader with raw kernel..."
    ./bootloader_starter.sh
    exit 0
elif [ "$1" = "simple" ]; then
    # Create an ultra-simple kernel with just basic MOV instructions
    echo "=== Creating ultra-simple kernel ==="
    mkdir -p esp/EFI/WOODIX
    
    # Use a handcrafted binary with just the essential opcodes
    echo -ne '\xB8\x00\x80\x0B\x00\xC6\x00\x58\xC6\x40\x01\x0F\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
    chmod +x esp/EFI/WOODIX/KERNEL.ELF
    
    echo "✅ Ultra-simple binary kernel created"
    echo "Running bootloader with simple kernel..."
    ./bootloader_starter.sh
    exit 0
fi

# Add explicit test option if not already present
if [ "$1" = "test" ]; then
    echo "=== Creating and testing with simplified test kernel ==="
    
    # Create proper directory structure
    mkdir -p esp/EFI/WOODIX
    mkdir -p esp/EFI/BOOT
    
    # Assemble the test kernel with nasm
    if command -v nasm > /dev/null; then
        echo "Assembling test kernel with NASM..."
        cd src/bootloader
        nasm -f bin test_kernel.asm -o ../../esp/EFI/WOODIX/KERNEL.ELF
        cd ../..
        
        # Create a copy in alternate locations the bootloader might check
        cp esp/EFI/WOODIX/KERNEL.ELF esp/EFI/BOOT/KERNEL.ELF
        cp esp/EFI/WOODIX/KERNEL.ELF esp/KERNEL.ELF
    else
        echo "NASM not found, creating binary kernel manually..."
        # Machine code for a simple kernel that writes OK!
        echo -ne '\x57\x44\x58\x4B\x52\x4E\x4C\x00\xB8\x00\x80\x0B\x00\x66\xC7\x00\x4F\x0A\x66\xC7\x40\x02\x4B\x0A\x66\xC7\x40\x04\x21\x0A\xFA\xF4\xEB\xFE' > esp/EFI/WOODIX/KERNEL.ELF
        
        # Create copies in alternate locations
        cp esp/EFI/WOODIX/KERNEL.ELF esp/EFI/BOOT/KERNEL.ELF
        cp esp/EFI/WOODIX/KERNEL.ELF esp/KERNEL.ELF
    fi
    
    # Set proper permissions
    chmod +x esp/EFI/WOODIX/KERNEL.ELF
    chmod +x esp/EFI/BOOT/KERNEL.ELF
    chmod +x esp/KERNEL.ELF
    
    echo "=== Directory listing for verification ==="
    find esp -type f | sort
    
    # Launch bootloader
    ./bootloader_starter.sh
    exit 0
fi

# Copy the built kernel to ESP
echo -e "\n=== Setting up ESP structure ==="
mkdir -p "esp/EFI/WOODIX"
cp "$KERNEL_BIN" "esp/EFI/WOODIX/KERNEL.ELF"
chmod +x "esp/EFI/WOODIX/KERNEL.ELF"

echo "✅ Kernel copied to esp/EFI/WOODIX/KERNEL.ELF"
ls -l esp/EFI/WOODIX/KERNEL.ELF

# Run the bootloader script if requested
if [ "$1" = "run" ]; then
    echo "=== Running bootloader ==="
    ./bootloader_starter.sh
fi

echo "=== Build completed successfully ==="
