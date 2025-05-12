#include <efi.h>
#include <efilib.h>

// Change to match where your script actually puts the kernel file
#define KERNEL_PATH L"\\EFI\\WOODIX\\KERNEL.ELF"

// For debugging, attempt multiple paths with different casing (UEFI can be case-sensitive)
#define KERNEL_PATH_ALT1 L"\\efi\\woodix\\kernel.elf"
#define KERNEL_PATH_ALT2 L"\\KERNEL.ELF"

// Additional backup paths to try
#define KERNEL_PATH_ALT3 L"\\EFI\\BOOT\\KERNEL.ELF"
#define KERNEL_PATH_ALT4 L"\\BOOTX64.ELF"

// Kernel entry point type definition
typedef void (*KernelEntry)(void);

// Simple GDT for transitioning to protected/long mode
typedef struct {
    UINT16 limit_low;
    UINT16 base_low;
    UINT8  base_middle;
    UINT8  access;
    UINT8  granularity;
    UINT8  base_high;
} __attribute__((packed)) GDT_ENTRY;

typedef struct {
    UINT16 limit;
    UINT64 base;
} __attribute__((packed)) GDTR;

// Function to set up a basic 64-bit GDT
void setup_gdt(GDT_ENTRY *gdt, GDTR *gdtr) {
    // Null descriptor
    gdt[0].limit_low = 0;
    gdt[0].base_low = 0;
    gdt[0].base_middle = 0;
    gdt[0].access = 0;
    gdt[0].granularity = 0;
    gdt[0].base_high = 0;

    // Code segment descriptor (64-bit)
    gdt[1].limit_low = 0xFFFF;
    gdt[1].base_low = 0;
    gdt[1].base_middle = 0;
    gdt[1].access = 0x9A;      // Present, Ring 0, Code segment, Executable, Readable
    gdt[1].granularity = 0x20; // 64-bit code
    gdt[1].base_high = 0;

    // Data segment descriptor
    gdt[2].limit_low = 0xFFFF;
    gdt[2].base_low = 0;
    gdt[2].base_middle = 0;
    gdt[2].access = 0x92;      // Present, Ring 0, Data segment, Writable
    gdt[2].granularity = 0;
    gdt[2].base_high = 0;

    // Set up GDTR
    gdtr->limit = sizeof(GDT_ENTRY) * 3 - 1;
    gdtr->base = (UINT64)gdt;
}

// Add embedded minimal kernel for fallback
static const UINT8 EmbeddedKernel[] = {
    0xB8, 0x00, 0x80, 0x0B, 0x00,           // mov eax, 0xB8000
    0x66, 0xC7, 0x00, 0x4F, 0x0A,           // mov word [eax], 0x0A4F ('O' in green)
    0x66, 0xC7, 0x40, 0x02, 0x4B, 0x0A,     // mov word [eax+2], 0x0A4B ('K' in green)
    0x66, 0xC7, 0x40, 0x04, 0x21, 0x0A,     // mov word [eax+4], 0x0A21 ('!' in green)
    0xFA,                                   // cli
    0xF4,                                   // hlt
    0xEB, 0xFE                              // jmp $ (infinite loop)
};

// Function to load the kernel file from the boot device
EFI_STATUS LoadKernel(EFI_HANDLE ImageHandle, VOID **KernelBuffer, UINTN *KernelSize) {
    EFI_STATUS Status;
    EFI_LOADED_IMAGE *LoadedImage = NULL;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *FileSystem = NULL;
    EFI_FILE_PROTOCOL *Root = NULL;
    EFI_FILE_PROTOCOL *KernelFile = NULL;
    BOOLEAN UseEmbeddedKernel = FALSE;
    
    // Get the loaded image protocol interface
    Status = uefi_call_wrapper(BS->HandleProtocol, 3, ImageHandle, 
                              &gEfiLoadedImageProtocolGuid, (VOID**)&LoadedImage);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get LoadedImageProtocol: %r\n", Status);
        UseEmbeddedKernel = TRUE;
        goto UseEmbedded;
    }
    
    // Get the file system protocol from the device handle
    Status = uefi_call_wrapper(BS->HandleProtocol, 3, LoadedImage->DeviceHandle,
                              &gEfiSimpleFileSystemProtocolGuid, (VOID**)&FileSystem);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get FileSystemProtocol: %r\n", Status);
        UseEmbeddedKernel = TRUE;
        goto UseEmbedded;
    }
    
    // Open the volume/root directory
    Status = uefi_call_wrapper(FileSystem->OpenVolume, 2, FileSystem, &Root);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to open volume: %r\n", Status);
        UseEmbeddedKernel = TRUE;
        goto UseEmbedded;
    }
    
    Print(L"=== Filesystem accessed successfully ===\n");
    
    // Try all common paths for kernel
    const CHAR16 *KernelPaths[] = {
        L"\\EFI\\WOODIX\\KERNEL.ELF",
        L"\\EFI\\BOOT\\KERNEL.ELF",
        L"\\KERNEL.ELF",
        L"\\KERNEL",
        NULL
    };
    
    BOOLEAN KernelFound = FALSE;
    for (int i = 0; KernelPaths[i] != NULL; i++) {
        Print(L"Trying to open kernel at: %s\n", KernelPaths[i]);
        Status = uefi_call_wrapper(Root->Open, 5, Root, &KernelFile, KernelPaths[i], 
                                  EFI_FILE_MODE_READ, 0);
        if (!EFI_ERROR(Status)) {
            Print(L"Found kernel at: %s\n", KernelPaths[i]);
            KernelFound = TRUE;
            break;
        }
    }
    
    // If kernel not found, create a basic one directly
    if (!KernelFound) {
        Print(L"No kernel found, listing files to debug...\n");

        // List root contents for debugging
        EFI_FILE_INFO *FileInfo;
        UINTN FileInfoSize = sizeof(EFI_FILE_INFO) + 200;
        Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, FileInfoSize, (VOID**)&FileInfo);
        
        if (!EFI_ERROR(Status)) {
            Print(L"Root directory contents:\n");
            uefi_call_wrapper(Root->SetPosition, 2, Root, 0);
            UINTN BufferSize;
            while (1) {
                BufferSize = FileInfoSize;
                Status = uefi_call_wrapper(Root->Read, 3, Root, &BufferSize, FileInfo);
                if (EFI_ERROR(Status) || BufferSize == 0) break;
                
                Print(L"  %s\n", FileInfo->FileName);
            }
            
            uefi_call_wrapper(BS->FreePool, 1, FileInfo);
        }
        
        Print(L"Creating kernel directly in memory\n");
        UseEmbeddedKernel = TRUE;
    }
    
UseEmbedded:
    if (UseEmbeddedKernel) {
        Print(L"Using embedded kernel\n");
        
        // Use the embedded kernel
        *KernelSize = sizeof(EmbeddedKernel);
        Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, *KernelSize, KernelBuffer);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to allocate memory for embedded kernel: %r\n", Status);
            return Status;
        }
        
        // Copy the embedded kernel
        CopyMem(*KernelBuffer, EmbeddedKernel, *KernelSize);
        Print(L"Embedded kernel loaded successfully (%d bytes)\n", *KernelSize);
        return EFI_SUCCESS;
    }
    
    // Get kernel file info to determine its size
    EFI_FILE_INFO *FileInfo;
    UINTN FileInfoSize = sizeof(EFI_FILE_INFO) + 100;
    Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, FileInfoSize, (VOID**)&FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for file info: %r\n", Status);
        UseEmbeddedKernel = TRUE;
        goto UseEmbedded;
    }
    
    Status = uefi_call_wrapper(KernelFile->GetInfo, 4, KernelFile, &gEfiFileInfoGuid, 
                              &FileInfoSize, FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get kernel file info: %r\n", Status);
        uefi_call_wrapper(BS->FreePool, 1, FileInfo);
        UseEmbeddedKernel = TRUE;
        goto UseEmbedded;
    }
    
    // Allocate memory for the kernel
    *KernelSize = FileInfo->FileSize;
    Print(L"Kernel size from file: %d bytes\n", *KernelSize);
    
    Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, *KernelSize, KernelBuffer);
    uefi_call_wrapper(BS->FreePool, 1, FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for kernel: %r\n", Status);
        UseEmbeddedKernel = TRUE;
        goto UseEmbedded;
    }
    
    // Read the kernel file
    Status = uefi_call_wrapper(KernelFile->Read, 3, KernelFile, KernelSize, *KernelBuffer);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to read kernel file: %r\n", Status);
        uefi_call_wrapper(BS->FreePool, 1, *KernelBuffer);
        UseEmbeddedKernel = TRUE;
        goto UseEmbedded;
    }

    // Close the file and volume
    uefi_call_wrapper(KernelFile->Close, 1, KernelFile);
    uefi_call_wrapper(Root->Close, 1, Root);
    
    Print(L"Kernel loaded from file successfully (%d bytes)\n", *KernelSize);
    return EFI_SUCCESS;
}

// Simplified kernel handoff approach
EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    // Initialize UEFI environment
    InitializeLib(ImageHandle, SystemTable);
    
    // Clear screen
    uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);
    
    // Display messages
    Print(L"Woodix Bootloader\n\n");
    Print(L"Loading Woodix OS...\n");
    
    // Load the kernel (either from file or use embedded)
    VOID *KernelBuffer = NULL;
    UINTN KernelSize = 0;
    
    EFI_STATUS Status = LoadKernel(ImageHandle, &KernelBuffer, &KernelSize);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to load kernel: %r\n", Status);
        uefi_call_wrapper(BS->Stall, 1, 10000000); // Stall for 10 seconds
        return Status;
    }
    
    Print(L"Kernel Loaded! (%d bytes)\n", KernelSize);
    
    // Direct-to-memory approach for kernels
    UINT8 *directKernel = (UINT8*)0x100000;  // 1MB physical address
    
    // Copy the kernel directly to the 1MB physical address
    Print(L"Copying kernel to physical address 0x100000\n");
    
    // Simple memory copy, byte by byte
    for (UINTN i = 0; i < KernelSize; i++) {
        directKernel[i] = ((UINT8*)KernelBuffer)[i];
    }
    
    // Free the original buffer
    uefi_call_wrapper(BS->FreePool, 1, KernelBuffer);
    
    Print(L"Kernel copied. Preparing to transfer control...\n");
    
    // Prepare a GDT for the kernel
    GDT_ENTRY gdt[3];
    GDTR gdtr;
    setup_gdt(gdt, &gdtr);
    Print(L"GDT Done\n");

    // Completely overhauled memory map handling
    UINTN MapKey = 0;
    UINTN MemoryMapSize = 0;
    UINTN DescriptorSize = 0;
    UINT32 DescriptorVersion = 0;
    EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;
    
    // Step 1: First call to determine size (with NULL buffer)
    Status = uefi_call_wrapper(BS->GetMemoryMap, 5, &MemoryMapSize, NULL, NULL, 
                            &DescriptorSize, &DescriptorVersion);
                            
    // Expected to fail with BUFFER_TOO_SMALL
    if (Status != EFI_BUFFER_TOO_SMALL) {
        Print(L"Unexpected error getting memory map size: %r\n", Status);
        return Status;
    }
    
    // Step 2: Allocate more memory than requested to account for changes
    // This is critical - the memory map can grow between calls
    MemoryMapSize += 2 * DescriptorSize; // For potential new entries
    MemoryMapSize += 4096;               // Extra safety padding
    
    // Step 3: Allocate memory for the map
    Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, MemoryMapSize, (VOID**)&MemoryMap);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for memory map: %r\n", Status);
        return Status;
    }
    
    // Step 4: Zero the memory (important for safety)
    ZeroMem(MemoryMap, MemoryMapSize);
    
    // Step 5: Get the actual memory map
    // CRITICAL: Make no allocations between here and ExitBootServices
    Status = uefi_call_wrapper(BS->GetMemoryMap, 5, &MemoryMapSize, MemoryMap, &MapKey, 
                            &DescriptorSize, &DescriptorVersion);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get memory map: %r\n", Status);
        uefi_call_wrapper(BS->FreePool, 1, MemoryMap);
        return Status;
    }
    
    Print(L"Memory map acquired. Key: %d, Size: %d, Descriptor Size: %d\n", 
          MapKey, MemoryMapSize, DescriptorSize);
    
    // Step 6: Try to exit boot services IMMEDIATELY after getting memory map
    // No Print() or other functions that might allocate memory should be called
    Status = uefi_call_wrapper(BS->ExitBootServices, 2, ImageHandle, MapKey);
    
    // If we get here with an error, ExitBootServices failed
    if (EFI_ERROR(Status)) {
        Print(L"ExitBootServices failed: %r\n", Status);
        Print(L"Trying alternate approach with direct memory map fetch...\n");
        
        // Free the old memory map
        uefi_call_wrapper(BS->FreePool, 1, MemoryMap);
        MemoryMap = NULL;
        
        // Get a fresh memory map with no intermediate steps
        MemoryMapSize = 0;
        Status = uefi_call_wrapper(BS->GetMemoryMap, 5, &MemoryMapSize, NULL, NULL, 
                                &DescriptorSize, &DescriptorVersion);
        
        // Add even more buffer space
        MemoryMapSize += 8 * DescriptorSize; // Much larger buffer
        Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, MemoryMapSize, (VOID**)&MemoryMap);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to allocate memory on retry: %r\n", Status);
            return Status;
        }
        
        // Get the memory map and IMMEDIATELY call ExitBootServices
        Status = uefi_call_wrapper(BS->GetMemoryMap, 5, &MemoryMapSize, MemoryMap, &MapKey, 
                                &DescriptorSize, &DescriptorVersion);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to get memory map on retry: %r\n", Status);
            uefi_call_wrapper(BS->FreePool, 1, MemoryMap);
            return Status;
        }
        
        // Final attempt to exit boot services, no prints or other allocations
        Status = uefi_call_wrapper(BS->ExitBootServices, 2, ImageHandle, MapKey);
        if (EFI_ERROR(Status)) {
            // We've failed twice now, no point in continuing
            Print(L"Final attempt to exit boot services failed: %r\n", Status);
            Print(L"This UEFI implementation may have issues with ExitBootServices.\n");
            Print(L"Stalling for 10 seconds before giving up...\n");
            uefi_call_wrapper(BS->Stall, 1, 10000000); // 10 second delay
            return Status;
        }
    }
    
    // If we reach here, we've successfully exited boot services
    // Note: No more BS->xxx calls can be made after this point!
    
    // Load the prepared GDT
    __asm__ volatile ("lgdt %0" : : "m" (gdtr));
    
    // Set up segments
    __asm__ volatile (
        "movw $0x10, %%ax\n"   // Data segment selector (index 2)
        "movw %%ax, %%ds\n"
        "movw %%ax, %%es\n"
        "movw %%ax, %%fs\n"
        "movw %%ax, %%gs\n"
        "movw %%ax, %%ss\n"
        // Far jump to set CS
        "pushq $0x08\n"        // Code segment selector (index 1)
        "leaq 1f(%%rip), %%rax\n"
        "pushq %%rax\n"
        "lretq\n"
        "1:\n"
        : : : "rax", "memory"
    );
    
    // Jump directly to the kernel at 1MB (0x100000)
    KernelEntry KernelMain = (KernelEntry)0x100000;
    KernelMain();
    
    // We should never reach here
    return EFI_LOAD_ERROR;
}
