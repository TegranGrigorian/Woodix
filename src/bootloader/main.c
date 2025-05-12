#include <efi.h>
#include <efilib.h>

// Change to match where your script actually puts the kernel file
#define KERNEL_PATH L"\\EFI\\WOODIX\\KERNEL.ELF"

// For debugging, attempt multiple paths
#define KERNEL_PATH_ALT1 L"\\EFI\\BOOT\\WOODKRNL.ELF"
#define KERNEL_PATH_ALT2 L"\\KERNEL.ELF"

// Kernel entry point type definition
typedef void (*KernelEntry)(void);

// Function to load the kernel file from the boot device
EFI_STATUS LoadKernel(EFI_HANDLE ImageHandle, VOID **KernelBuffer, UINTN *KernelSize) {
    EFI_STATUS Status;
    EFI_LOADED_IMAGE *LoadedImage = NULL;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *FileSystem = NULL;
    EFI_FILE_PROTOCOL *Root = NULL;
    EFI_FILE_PROTOCOL *KernelFile = NULL;
    
    // Get the loaded image protocol interface
    Status = uefi_call_wrapper(BS->HandleProtocol, 3, ImageHandle, 
                              &gEfiLoadedImageProtocolGuid, (VOID**)&LoadedImage);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get LoadedImageProtocol: %r\n", Status);
        return Status;
    }
    
    // Get the file system protocol from the device handle
    Status = uefi_call_wrapper(BS->HandleProtocol, 3, LoadedImage->DeviceHandle,
                              &gEfiSimpleFileSystemProtocolGuid, (VOID**)&FileSystem);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get FileSystemProtocol: %r\n", Status);
        return Status;
    }
    
    // Open the volume/root directory
    Status = uefi_call_wrapper(FileSystem->OpenVolume, 2, FileSystem, &Root);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to open volume: %r\n", Status);
        return Status;
    }
    
    // Try to open the kernel file with the primary path
    Print(L"Attempting to open kernel at %s\n", KERNEL_PATH);
    Status = uefi_call_wrapper(Root->Open, 5, Root, &KernelFile, KERNEL_PATH, 
                              EFI_FILE_MODE_READ, 0);
    
    // If primary path fails, try alternate paths
    if (EFI_ERROR(Status)) {
        Print(L"Failed to open primary kernel path, trying alternative paths\n");
        
        Print(L"Attempting to open kernel at %s\n", KERNEL_PATH_ALT1);
        Status = uefi_call_wrapper(Root->Open, 5, Root, &KernelFile, KERNEL_PATH_ALT1, 
                                  EFI_FILE_MODE_READ, 0);
                                  
        if (EFI_ERROR(Status)) {
            Print(L"Attempting to open kernel at %s\n", KERNEL_PATH_ALT2);
            Status = uefi_call_wrapper(Root->Open, 5, Root, &KernelFile, KERNEL_PATH_ALT2, 
                                      EFI_FILE_MODE_READ, 0);
                                      
            if (EFI_ERROR(Status)) {
                Print(L"Failed to open kernel file: %r\n", Status);
                return Status;
            }
        }
    }
    
    // Get kernel file info to determine its size
    EFI_FILE_INFO *FileInfo;
    UINTN FileInfoSize = sizeof(EFI_FILE_INFO) + 100;
    Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, FileInfoSize, (VOID**)&FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for file info: %r\n", Status);
        return Status;
    }
    
    Status = uefi_call_wrapper(KernelFile->GetInfo, 4, KernelFile, &gEfiFileInfoGuid, 
                              &FileInfoSize, FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to get kernel file info: %r\n", Status);
        uefi_call_wrapper(BS->FreePool, 1, FileInfo);
        return Status;
    }
    
    // Allocate memory for the kernel
    *KernelSize = FileInfo->FileSize;
    Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, *KernelSize, KernelBuffer);
    uefi_call_wrapper(BS->FreePool, 1, FileInfo);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to allocate memory for kernel: %r\n", Status);
        return Status;
    }
    
    // Read the kernel file
    Status = uefi_call_wrapper(KernelFile->Read, 3, KernelFile, KernelSize, *KernelBuffer);
    if (EFI_ERROR(Status)) {
        Print(L"Failed to read kernel file: %r\n", Status);
        uefi_call_wrapper(BS->FreePool, 1, *KernelBuffer);
        return Status;
    }
    
    // Check if it has an ELF header, but don't fail if it doesn't
    UINT8* FileData = (UINT8*)*KernelBuffer;
    if (FileData[0] == 0x7F && FileData[1] == 'E' && FileData[2] == 'L' && FileData[3] == 'F') {
        Print(L"Kernel has valid ELF header\n");
    } else {
        Print(L"Kernel doesn't have ELF header, assuming flat binary\n");
    }
    
    // Close the file and volume
    uefi_call_wrapper(KernelFile->Close, 1, KernelFile);
    uefi_call_wrapper(Root->Close, 1, Root);
    
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
    
    // Load the kernel
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
    
    // Exit boot services
    UINTN MapKey;
    UINTN MemoryMapSize = 0;
    UINTN DescriptorSize;
    UINT32 DescriptorVersion;
    EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;
    
    // Get memory map (required to exit boot services)
    Status = uefi_call_wrapper(BS->GetMemoryMap, 5, &MemoryMapSize, MemoryMap, &MapKey, 
                             &DescriptorSize, &DescriptorVersion);
    
    // We expect the buffer to be too small
    if (Status == EFI_BUFFER_TOO_SMALL) {
        // Add some extra space to account for potential changes between calls
        MemoryMapSize += 1024;
        
        Status = uefi_call_wrapper(BS->AllocatePool, 3, EfiLoaderData, MemoryMapSize, (VOID**)&MemoryMap);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to allocate memory for memory map: %r\n", Status);
            return Status;
        }
        
        Status = uefi_call_wrapper(BS->GetMemoryMap, 5, &MemoryMapSize, MemoryMap, &MapKey, 
                                 &DescriptorSize, &DescriptorVersion);
        if (EFI_ERROR(Status)) {
            Print(L"Failed to get memory map: %r\n", Status);
            return Status;
        }
    } else if (EFI_ERROR(Status)) {
        Print(L"Failed to get memory map size: %r\n", Status);
        return Status;
    }
    
    // Exit boot services
    Status = uefi_call_wrapper(BS->ExitBootServices, 2, ImageHandle, MapKey);
    if (EFI_ERROR(Status)) {
        // If we fail, we can't really print anything since we may have partially shut down services
        return Status;
    }
    
    // Jump directly to the kernel at 1MB
    KernelEntry KernelMain = (KernelEntry)0x100000;
    KernelMain();
    
    // We should never reach here
    return EFI_LOAD_ERROR;
}
