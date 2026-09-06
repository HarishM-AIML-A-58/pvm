# Portable QEMU for Windows

To run without installing QEMU on the host Windows computer, place the portable QEMU Windows binaries in this directory:

Expected file path:
`backends\windows\qemu\qemu-system-x86_64.exe`

### Download Instructions:
1. Download official Windows binaries from https://qemu.weilnetz.de/w64/ or https://github.com/StefanScherer/qemu-windows/releases
2. Extract the contents so that `qemu-system-x86_64.exe` and supporting DLLs / `share/` folder reside directly in this directory:
   ```
   backends/windows/qemu/
   ├── qemu-system-x86_64.exe
   ├── qemu-img.exe
   ├── *.dll
   └── share/
       └── edk2-x86_64-code.fd (UEFI firmware)
   ```

Note: If QEMU is installed on the host system and available in `PATH`, the launcher will automatically detect and use it as a fallback!
