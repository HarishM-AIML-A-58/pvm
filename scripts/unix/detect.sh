#!/usr/bin/env bash
# Host hardware & virtualization capability detector for Linux and macOS

detect_host_info() {
    local root_dir="$1"

    HOST_OS=$(uname -s)
    HOST_ARCH=$(uname -m)
    HOST_CPU_NAME="Unknown CPU"
    HOST_PHYSICAL_CORES=1
    HOST_LOGICAL_CORES=1
    HOST_TOTAL_RAM_MB=2048
    HOST_AVAIL_RAM_MB=1024
    VIRT_HW_SUPPORT=0
    KVM_AVAILABLE=0
    HVF_AVAILABLE=0
    QEMU_PATH=""
    QEMU_VERSION="Not Found"
    QEMU_ACCELS=""

    # 1. OS-specific CPU and Memory detection
    if [ "$HOST_OS" = "Linux" ]; then
        HOST_LOGICAL_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
        HOST_CPU_NAME=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "Linux CPU")
        
        # Calculate RAM in MB
        if [ -f /proc/meminfo ]; then
            local total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            local avail_kb=$(grep -E 'MemAvailable|MemFree' /proc/meminfo | head -n1 | awk '{print $2}')
            HOST_TOTAL_RAM_MB=$(( total_kb / 1024 ))
            HOST_AVAIL_RAM_MB=$(( avail_kb / 1024 ))
        fi

        # Check KVM & Hardware Virtualization
        if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
            VIRT_HW_SUPPORT=1
        fi
        if [ -w /dev/kvm ]; then
            KVM_AVAILABLE=1
        elif [ -e /dev/kvm ]; then
            KVM_AVAILABLE=1
        fi

    elif [ "$HOST_OS" = "Darwin" ]; then
        HOST_LOGICAL_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
        HOST_CPU_NAME=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon / Intel")
        
        local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 2147483648)
        HOST_TOTAL_RAM_MB=$(( mem_bytes / 1048576 ))
        
        # Approximate free RAM on macOS using vm_stat
        local pages_free=$(vm_stat 2>/dev/null | grep "Pages free" | awk '{print $3}' | tr -d '.')
        local pages_inactive=$(vm_stat 2>/dev/null | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        if [ -n "$pages_free" ] && [ -n "$pages_inactive" ]; then
            HOST_AVAIL_RAM_MB=$(( (pages_free + pages_inactive) * 4096 / 1048576 ))
        else
            HOST_AVAIL_RAM_MB=$(( HOST_TOTAL_RAM_MB / 2 ))
        fi

        VIRT_HW_SUPPORT=1
        HVF_AVAILABLE=1
    fi

    # 2. Locate QEMU Binary
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        QEMU_PATH=$(command -v qemu-system-x86_64)
    elif [ -x "$root_dir/backends/linux/qemu/qemu-system-x86_64" ]; then
        QEMU_PATH="$root_dir/backends/linux/qemu/qemu-system-x86_64"
    elif [ -x "/usr/local/bin/qemu-system-x86_64" ]; then
        QEMU_PATH="/usr/local/bin/qemu-system-x86_64"
    elif [ -x "/opt/homebrew/bin/qemu-system-x86_64" ]; then
        QEMU_PATH="/opt/homebrew/bin/qemu-system-x86_64"
    fi

    if [ -n "$QEMU_PATH" ]; then
        QEMU_VERSION=$("$QEMU_PATH" --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "Unknown")
        QEMU_ACCELS=$("$QEMU_PATH" -accel help 2>&1 | tr '\n' ' ')
    fi
}
