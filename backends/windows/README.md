# Portable QEMU for Windows

QEMU binaries are **not bundled** and must be installed separately (see Setup below).
They are placed here by the `setup.bat` / `PortableVM_Setup.exe` installer wizard.

## Architecture-Specific Binaries

| Host Architecture | `$env:PROCESSOR_ARCHITECTURE` | Binary Required |
|---|---|---|
| Intel / AMD 64-bit | `AMD64` | `qemu-system-x86_64.exe` |
| ARM 64-bit | `ARM64` | `qemu-system-aarch64.exe` |

The setup wizard auto-detects your architecture and guides you to the correct binary.

## Expected Structure

After setup, this folder should look like:

```
backends/windows/qemu/
├── qemu-system-x86_64.exe   (AMD64 hosts)
│   OR
├── qemu-system-aarch64.exe  (ARM64 hosts)
├── qemu-img.exe
├── *.dll
└── share/
    └── edk2-x86_64-code.fd  (optional - UEFI firmware)
```

## Download Instructions (Manual)

1. Visit the official QEMU Windows binaries page: https://qemu.weilnetz.de/w64/
2. Download the installer (`.exe`) or archive (`.zip`) for your architecture.
3. Extract or install so that `qemu-system-{arch}.exe` and supporting DLLs reside
   directly in this `qemu/` directory.

> **Note:** If QEMU is installed system-wide and available in `PATH`, the launcher
> will automatically detect and use it as a fallback.
