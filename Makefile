TARGET = kernel
BUILD_DIR = build
CUSTOM_TARGET = i686-custom.json

all: $(BUILD_DIR)/$(TARGET).bin

$(BUILD_DIR)/$(TARGET).bin: src/main.rs
	mkdir -p $(BUILD_DIR)
	cargo build --target $(CUSTOM_TARGET) --release
	cp target/$(CUSTOM_TARGET)/release/kernel $(BUILD_DIR)/$(TARGET).bin

run: all
	qemu-system-i386 -kernel $(BUILD_DIR)/$(TARGET).bin

clean:
	rm -rf $(BUILD_DIR) target
