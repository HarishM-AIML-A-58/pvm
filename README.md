<div align="center">
  <h1>🚀 PortableVM (v0.1-beta)</h1>
  <p><strong>Your entire operating system in your pocket. Plug it in. Run it anywhere.</strong></p>
</div>

---

## 🌟 What is PortableVM?

**PortableVM** is a zero-dependency, ultra-lightweight launcher and virtualization environment that lives entirely on an external USB drive or SSD. 

Instead of carrying a laptop, just carry your portable SSD. Plug it into **any** host computer (Windows, Linux, or macOS), double-click the launcher, and instantly boot into your own persistent, personalized operating system running at near-native speeds.

- **Zero Installation on Host**: No need to install hypervisors or dependencies on the host machine. 
- **Hardware-Aware Engine**: Automatically inspects the host computer's CPU and RAM to safely allocate optimal resources to your VM without starving the host OS.
- **Cross-Platform Compatibility**: Uses native PowerShell (Windows) or Bash (Linux/macOS) wrappers.
- **Hardware Acceleration**: Automatically leverages WHPX (Windows), KVM (Linux), or HVF (macOS) for blistering fast near-native performance.

---

## 📥 Installation & Setup

We have packaged the entire PortableVM setup into a single, dead-simple installer file.

### Step 1: Download the Installer
Go to the **Releases** page of this repository and download the latest **`PortableVM_Setup.bat`**.

### Step 2: Run the Installer (Windows)
1. Plug in your external USB Drive or SSD.
2. Double-click the downloaded **`PortableVM_Setup.bat`** file.
3. The interactive GUI wizard will appear. 
4. The wizard will automatically detect your plugged-in USB drive, ensure it has enough free space, and prompt you to choose an installation folder.
5. It will securely download QEMU (the underlying virtualization engine) and extract all necessary PortableVM files directly to your USB drive.

> **Note on Upgrading:** If you already have a version of PortableVM installed, simply run the new `.bat` file and point it to your existing directory. The installer will safely upgrade the internal scripts while preserving your VMs and configurations!

---

## 💻 Accessing & Using Your PortableVM

Once installed, navigate to the `PortableVM` folder on your USB drive.

### 1. Launch the GUI Dashboard
To manage your VMs, create new ones, or interactively adjust RAM and CPU limits based on the current host machine:
- **Windows**: Double-click **`launch_gui.bat`**
- **Linux / macOS**: Execute **`./launch_gui.sh`**

### 2. Creating a Virtual Machine
Inside the GUI Launcher, click **"+ New VM"**. You can:
- Mount an `.iso` file (like Ubuntu, Debian, or Windows) to install a fresh OS.
- Define your virtual disk size (e.g., 64GB).
- The launcher will automatically spin up the QEMU instance and guide you through your OS installation.

### 3. Quick Launching
If you don't need the GUI and just want to boot your default VM immediately from the terminal:
- **Windows**: Double-click `launch.bat`
- **Linux / macOS**: Run `./launch.sh`

---

## ⚡ Virtualization Acceleration (Optional but Recommended)

For maximum performance, PortableVM attempts to use hardware acceleration. Ensure your host machine has virtualization enabled in the BIOS.

- **Windows**: Ensure **Windows Hypervisor Platform** is enabled in Windows Features.
- **Linux**: Ensure your user has access to `/dev/kvm`.
- **macOS**: Hypervisor.framework (`HVF`) is enabled automatically on modern macOS.

---
*PortableVM is currently in v0.1-beta.*
