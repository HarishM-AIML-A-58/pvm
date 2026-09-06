# Portable Virtual Machine Launcher

A zero-dependency, cross-platform **hardware detection, decision making, and launcher system** stored entirely on an external SSD.

It allows you to plug your SSD into any **Windows, Linux, or macOS** host computer and immediately launch your persistent personal Linux VM environment at near-native hypervisor speeds.

---

## 🌟 Key Features

- **Zero Host Dependencies**: Uses native PowerShell on Windows and Bash on Linux/macOS. No Python, node, or runtime installation needed.
- **Hardware-Aware Decision Engine**: Automatically inspects host CPU cores, RAM, and virtualization extensions to allocate safe, optimal resources without starving the host.
- **Interactive Configuration Review & Safe Limits**:
  - View detected hardware and calculated VM resources before launch.
  - Interactively customize Memory (RAM), CPU cores, Display backend, or SSH port.
  - **Upper Safe Limit Guard**: Displays a warning if requested RAM exceeds free memory required by running host programs or total physical RAM.
  - **Lower Safe Limit Guard**: Displays a warning if requested RAM drops below the minimum required limit (1024 MB) for the guest OS.
- **Hardware Acceleration**:
  - **Windows**: Windows Hypervisor Platform (`WHPX`)
  - **Linux**: Kernel-based Virtual Machine (`KVM`)
  - **macOS**: Hypervisor.framework (`HVF`)
  - **Fallback**: Tiny Code Generator (`TCG`) software emulation if hardware acceleration is unavailable
- **Multi-VM Support**: Place multiple VM instances under `vms/` and select which one to boot from an interactive menu.
- **Relative Path Portability**: Automatically computes its SSD root path regardless of drive letter (`E:`, `D:`, etc.) or Unix mount point.


---

## 📁 Directory Structure

```text
[SSD Root]
├── launch.bat                     # Double-click to launch on Windows
├── launch.sh                      # Execute to launch on Linux/macOS
├── config.json                    # Global resource allocation defaults
├── scripts/
│   ├── windows/                   # Native PowerShell modules
│   │   ├── detect.ps1             # Hardware & capability detector
│   │   ├── decide.ps1             # Decision engine (RAM, CPU, WHPX)
│   │   ├── build_command.ps1      # QEMU command builder
│   │   ├── display.ps1            # Terminal UI & formatting
│   │   └── launcher.ps1           # Windows orchestrator
│   └── unix/                      # Native Bash modules
│       ├── detect.sh              # Hardware & capability detector
│       ├── decide.sh              # Decision engine (RAM, CPU, KVM/HVF)
│       ├── build_command.sh       # QEMU command builder
│       ├── display.sh             # Terminal UI & formatting
│       └── launcher.sh            # Unix orchestrator
├── vms/                           # VM storage directory
│   └── default-linux/             # Example VM folder
│       ├── disk.qcow2             # Virtual disk (user's OS + data)
│       └── vm.conf                # Optional per-VM override settings
└── backends/
    └── windows/
        └── qemu/                  # Place portable QEMU Windows binaries here
```

---

## 🚀 How to Use

### On Windows
Simply **double-click** `launch.bat` or run from PowerShell/CMD:
```cmd
launch.bat
```

Command-line flags:
```cmd
launch.bat -DetectOnly      # Inspect host hardware without starting VM
launch.bat -DryRun          # Generate and display QEMU command line
launch.bat -ListVMs         # List available VMs
launch.bat -VmName <name>   # Direct-boot specific VM
```

### On Linux / macOS
Run in terminal:
```bash
./launch.sh
```

Command-line flags:
```bash
./launch.sh --detect-only
./launch.sh --dry-run
./launch.sh --list-vms
./launch.sh --vm-name <name>
```

---

## ⚙️ Adding a New Virtual Machine

1. Create a new folder inside `vms/`:
   ```bash
   mkdir vms/my-workspace
   ```
2. Place your `disk.qcow2` virtual disk image inside `vms/my-workspace/`.
3. (Optional) Copy `vms/default-linux/vm.conf` into `vms/my-workspace/vm.conf` and adjust any custom resource limits.

---

## ⚡ Virtualization Acceleration Setup

- **Windows**: Ensure **Virtualization** is enabled in BIOS and **Windows Hypervisor Platform** is enabled in Windows Features:
  ```powershell
  Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All
  ```
- **Linux**: Ensure your user has access to `/dev/kvm`:
  ```bash
  sudo usermod -aG kvm $USER
  ```
- **macOS**: Hypervisor.framework (`HVF`) is enabled automatically on macOS 10.10+.
