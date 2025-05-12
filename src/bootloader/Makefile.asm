# Makefile for assembly UEFI bootloader - fixed version

ARCH            = x86_64
TARGET          = bootx64.efi
ASM_SOURCE      = bootloader.asm
ASM_OBJECT      = bootloader.o

# Tools
ASM             = nasm
LD              = ld
OBJCOPY         = objcopy

# Flags - Modified to address linking issues
ASM_FLAGS       = -f elf64 -g
LD_FLAGS        = -nostdlib -T $(EFI_LD_SCRIPT) -shared -Bsymbolic -L $(EFI_LIB_DIR)

# UEFI paths - May need adjustment for your system
EFI_LIB_DIR     = /usr/lib
EFI_LD_SCRIPT   = /usr/lib/elf_x86_64_efi.lds

# Output directories
ESP_DIR         = ../../esp/EFI/Boot

all: $(TARGET)

$(ASM_OBJECT): $(ASM_SOURCE)
	$(ASM) $(ASM_FLAGS) $< -o $@

$(TARGET): $(ASM_OBJECT)
	# Use direct ld command without the problematic --subsystem option
	$(LD) $(LD_FLAGS) -o $@ $< -lefi -lgnuefi
	# Make sure the file has the right format for UEFI
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel \
		-j .rela -j .reloc --target=efi-app-$(ARCH) $@ $@

install: $(TARGET)
	mkdir -p $(ESP_DIR)
	cp $(TARGET) $(ESP_DIR)/

clean:
	rm -f $(ASM_OBJECT) $(TARGET)

.PHONY: all install clean
