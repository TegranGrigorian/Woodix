TARGET = kernel
ARCH = i386
BUILD_DIR = build
BOOTLOADER = bootloader/bootloader.asm
KERNEL = kernel/main.rs

all: $(BUILD_DIR)/$(TARGET).bin

$(BUILD_DIR)/$(TARGET).bin: $(BOOTLOADER) $(KERNEL)
	mkdir -p $(BUILD_DIR)
	nasm -f bin $(BOOTLOADER) -o $(BUILD_DIR)/bootloader.bin
	cargo build --target $(ARCH)-unknown-none --release --manifest-path kernel/Cargo.toml
	cat $(BUILD_DIR)/bootloader.bin target/$(ARCH)-unknown-none/release/kernel > $(BUILD_DIR)/$(TARGET).bin

run: all
	qemu-system-$(ARCH) -kernel $(BUILD_DIR)/$(TARGET).bin

clean:
	rm -rf $(BUILD_DIR) target
