# Woodix Bootloader Makefile

# Variables
ARCH            = x86_64
TARGET          = bootx64
EFI_DIR         = /usr/include/efi
EFI_INCLUDES    = -I$(EFI_DIR) -I$(EFI_DIR)/$(ARCH) -I$(EFI_DIR)/protocol
EFI_LIB_DIR     = /usr/lib
CFLAGS          = -Wall -Wextra -fno-stack-protector -fshort-wchar -mno-red-zone -DEFI_FUNCTION_WRAPPER
LDFLAGS         = -nostdlib -znocombreloc -T $(EFI_LIB_DIR)/elf_$(ARCH)_efi.lds -shared -Bsymbolic $(EFI_LIB_DIR)/crt0-efi-$(ARCH).o
LIBS            = -L$(EFI_LIB_DIR) -lefi -lgnuefi

# Source files
SRCS = main.c
OBJS = $(SRCS:.c=.o)

# Targets
all: $(TARGET).efi

$(TARGET).efi: $(TARGET).so
	objcopy -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel \
		-j .rela -j .reloc --target=efi-app-$(ARCH) $< $@

$(TARGET).so: $(OBJS)
	ld $(LDFLAGS) $(OBJS) -o $@ $(LIBS)

%.o: %.c
	gcc $(CFLAGS) $(EFI_INCLUDES) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET).so $(TARGET).efi

.PHONY: all clean
