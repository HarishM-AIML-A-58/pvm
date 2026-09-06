# Virtual Machine Setup Guide

This folder holds the persistent virtual hard drive and configuration for this virtual machine instance.

---

## 📋 Prerequisites

1. An **OS Installer ISO file** (e.g., Ubuntu, Debian, Arch Linux, Fedora, Linux Mint) saved anywhere on your computer (e.g. `C:\Users\YourName\Downloads\ubuntu-24.04-desktop-amd64.iso`).
2. Portable QEMU binaries in `backends\windows\qemu\` (or QEMU installed on your host system).

---

## 🛠️ Step-by-Step Installation

### Step 1: Create the Virtual Disk (`disk.qcow2`)

Open a terminal at the **root directory of the SSD** (`D:\CODES\VM` or `E:\`):

#### On Windows (PowerShell / Command Prompt):
```cmd
cd /d D:\CODES\VM
backends\windows\qemu\qemu-img.exe create -f qcow2 vms\default-linux\disk.qcow2 64G
```

#### On Linux / macOS (Terminal):
```bash
cd /path/to/SSD
qemu-img create -f qcow2 vms/default-linux/disk.qcow2 64G
```

> [!NOTE]
> `64G` is the maximum dynamic capacity. The file only occupies **~200 KB** initially and expands automatically as you save files and install applications.

---

### Step 2: Boot the Installer ISO

Boot QEMU with the ISO mounted as a virtual CD-ROM and your new `disk.qcow2` as the primary hard drive:

#### On Windows (PowerShell):
```powershell
cd D:\CODES\VM
.\backends\windows\qemu\qemu-system-x86_64.exe `
  -name "Linux Installer" `
  -machine q35,accel=whpx,kernel-irqchip=off `
  -cpu max,vmx=off `
  -smp 4 `
  -m 4096 `
  -drive file=vms\default-linux\disk.qcow2,format=qcow2,if=virtio,cache=writeback `
  -cdrom "C:\Path\To\your-installer.iso" `
  -boot d `
  -vga virtio `
  -display sdl `
  -device qemu-xhci,id=xhci -device usb-tablet `
  -device intel-hda -device hda-duplex `
  -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0
```


#### On Linux (Bash):
```bash
qemu-system-x86_64 \
  -name "Linux Installer" \
  -machine q35,accel=kvm \
  -cpu host \
  -smp 4 \
  -m 4096 \
  -drive file=vms/default-linux/disk.qcow2,format=qcow2,if=virtio,cache=writeback \
  -cdrom "/path/to/your-installer.iso" \
  -boot d \
  -vga virtio \
  -display sdl \
  -device qemu-xhci,id=xhci -device usb-tablet \
  -device intel-hda -device hda-duplex \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0
```

---

### Step 3: Complete the OS Installation

1. The installer window will open. Follow the on-screen steps (choose language, keyboard layout, username, and password).
2. When prompted where to install, choose the virtual disk (**`vda`** / **VirtIO Block Device** / **QEMU HARDDISK**).
3. Let the installation finish.
4. When prompted to **"Restart Now"** or **"Reboot"**, shut down or close the VM window.

---

### Step 4: Launch and Use Your Portable VM

Once the installation is complete, you no longer need the ISO file!

From now on, simply run:
- **Windows**: Double-click **`launch.bat`**
- **Linux/macOS**: Run **`./launch.sh`**

The launcher will automatically:
1. Detect host hardware (CPU, RAM, virtualization support).
2. Present the interactive configuration review (allowing you to customize RAM/cores safely).
3. Start your persistent environment from `disk.qcow2`.

---

## ⚙️ Configuration & Customization (`vm.conf`)

You can customize this VM instance by editing [vm.conf](file:///d:/CODES/VM/vms/default-linux/vm.conf):

```ini
name=Ubuntu Workstation
memory_mb=4096
cores=4
display=sdl
network=nat
ssh_port=2222
uefi=true
disk=disk.qcow2
```

---

## 📦 Adding More VM Instances

To create a second VM (e.g. `vms/debian-server/`):
1. Create a new folder: `vms\debian-server\`
2. Create a disk inside it:
   ```cmd
   backends\windows\qemu\qemu-img.exe create -f qcow2 vms\debian-server\disk.qcow2 32G
   ```
3. Run the installer following Step 2 targeting `vms\debian-server\disk.qcow2`.
4. `launch.bat` will automatically discover all VMs and let you choose between them at boot!
