<#
.SYNOPSIS
    Decision Engine for VM Resource Allocation & Backend Selection.
.DESCRIPTION
    Translates host capabilities and VM configuration into an optimized launch specification.
#>

function Read-VMConfig {
    param(
        [string]$VmDir
    )

    $vmConfFile = Join-Path $VmDir "vm.conf"
    $overrides = @{}

    if (Test-Path $vmConfFile) {
        Get-Content $vmConfFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and -not $line.StartsWith(";")) {
                $parts = $line -split "=", 2
                if ($parts.Count -eq 2) {
                    $key = $parts[0].Trim().ToLower()
                    $val = $parts[1].Trim()
                    $overrides[$key] = $val
                }
            }
        }
    }

    return $overrides
}

function Invoke-DecisionEngine {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$HostInfo,

        [Parameter(Mandatory = $true)]
        [string]$RootDir,

        [Parameter(Mandatory = $true)]
        [string]$VmDir,

        [Parameter(Mandatory = $false)]
        [string]$GlobalConfigFile = (Join-Path $RootDir "config.json")
    )

    # 1. Load global defaults
    $globalConfig = $null
    if (Test-Path $GlobalConfigFile) {
        try {
            $globalConfig = Get-Content $GlobalConfigFile -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Could not parse config.json, using built-in defaults."
        }
    }

    $vmDefaults = $globalConfig.vm_defaults

    $memPercent = if ($vmDefaults.memory_percent) { $vmDefaults.memory_percent } else { 50 }
    $memMin = if ($vmDefaults.memory_min_mb) { $vmDefaults.memory_min_mb } else { 2048 }
    $memMax = if ($vmDefaults.memory_max_mb) { $vmDefaults.memory_max_mb } else { 16384 }

    $coresPercent = if ($vmDefaults.cores_percent) { $vmDefaults.cores_percent } else { 50 }
    $coresMin = if ($vmDefaults.cores_min) { $vmDefaults.cores_min } else { 2 }
    $coresMax = if ($vmDefaults.cores_max) { $vmDefaults.cores_max } else { 8 }

    $display = if ($vmDefaults.display) { $vmDefaults.display } else { "sdl" }
    $network = if ($vmDefaults.network) { $vmDefaults.network } else { "nat" }
    $sshPort = if ($vmDefaults.ssh_port) { $vmDefaults.ssh_port } else { 2222 }
    $uefi = if ($vmDefaults.uefi -ne $null) { $vmDefaults.uefi } else { $true }
    $arch = if ($vmDefaults.arch) { $vmDefaults.arch } else { "x86_64" }

    # 2. Read per-VM overrides if present
    $overrides = Read-VMConfig -VmDir $VmDir

    if ($overrides.ContainsKey("name")) { $vmName = $overrides["name"] } else { $vmName = (Split-Path $VmDir -Leaf) }
    if ($overrides.ContainsKey("memory_mb")) { $targetMemory = [int]$overrides["memory_mb"] } else { $targetMemory = $null }
    if ($overrides.ContainsKey("cores")) { $targetCores = [int]$overrides["cores"] } else { $targetCores = $null }
    if ($overrides.ContainsKey("display")) { $display = $overrides["display"] }
    if ($overrides.ContainsKey("network")) { $network = $overrides["network"] }
    if ($overrides.ContainsKey("ssh_port")) { $sshPort = [int]$overrides["ssh_port"] }
    if ($overrides.ContainsKey("uefi")) { $uefi = [bool]::Parse($overrides["uefi"]) }
    if ($overrides.ContainsKey("arch")) { $arch = $overrides["arch"] }

    # 3. Compute RAM Allocation
    $allocatedRam = 2048
    if ($targetMemory) {
        # Respect specific user request if it doesn't starve host
        $safeLimit = [math]::Max(512, $HostInfo.AvailableRamMB - 1024)
        if ($targetMemory -gt $safeLimit) {
            $allocatedRam = [math]::Max($memMin, $safeLimit)
        } else {
            $allocatedRam = $targetMemory
        }
    } else {
        # Percentage-based calculation
        $calcRam = [math]::Round(($HostInfo.TotalRamMB * $memPercent) / 100)
        # Cap at available RAM minus 1.5GB headroom for Windows host
        $maxSafe = [math]::Max($memMin, $HostInfo.AvailableRamMB - 1536)
        $allocatedRam = [math]::Min($calcRam, $maxSafe)
        # Clamp to bounds
        $allocatedRam = [math]::Max($memMin, [math]::Min($allocatedRam, $memMax))
    }

    # 4. Compute CPU Cores Allocation
    $hostCores = [math]::Max(1, $HostInfo.LogicalCores)
    $allocatedCores = 2
    if ($targetCores) {
        $allocatedCores = [math]::Min($targetCores, $hostCores)
    } else {
        $calcCores = [math]::Round(($hostCores * $coresPercent) / 100)
        $allocatedCores = [math]::Max($coresMin, [math]::Min($calcCores, $coresMax))
        $allocatedCores = [math]::Min($allocatedCores, $hostCores)
    }
    if ($allocatedCores -lt 1) { $allocatedCores = 1 }

    # 5. Determine Virtualization Acceleration Backend
    $selectedAccel = "tcg"
    $accelWarning = $null

    if ($HostInfo.WhpxAvailable) {
        $selectedAccel = "whpx"
    } elseif ($HostInfo.VirtFirmwareEnabled -and ($HostInfo.QemuAccelerators -contains "whpx")) {
        $selectedAccel = "whpx"
    } else {
        $selectedAccel = "tcg"
        $accelWarning = "Hardware acceleration (WHPX) is unavailable. Falling back to TCG software emulation (slower performance)."
    }

    # 6. Locate Disk Image
    $diskFiles = @("disk.qcow2", "vm.qcow2", "disk.raw", "disk.img")
    $selectedDisk = $null
    $diskFormat = "qcow2"

    if ($overrides.ContainsKey("disk")) {
        $customDisk = Join-Path $VmDir $overrides["disk"]
        if (Test-Path $customDisk) {
            $selectedDisk = (Resolve-Path $customDisk).Path
        }
    }

    if (-not $selectedDisk) {
        foreach ($candidate in $diskFiles) {
            $candidatePath = Join-Path $VmDir $candidate
            if (Test-Path $candidatePath) {
                $selectedDisk = (Resolve-Path $candidatePath).Path
                if ($candidate.EndsWith(".raw") -or $candidate.EndsWith(".img")) {
                    $diskFormat = "raw"
                }
                break
            }
        }
    }

    # 7. Check UEFI Firmware (EDK2 / OVMF)
    $uefiFirmware = $null
    if ($uefi) {
        $possibleFirmwares = @(
            (Join-Path $RootDir "backends\windows\qemu\share\edk2-x86_64-code.fd"),
            (Join-Path $RootDir "backends\windows\qemu\share\qemu\edk2-x86_64-code.fd"),
            (Join-Path (Split-Path $HostInfo.QemuPath) "share\edk2-x86_64-code.fd"),
            (Join-Path (Split-Path $HostInfo.QemuPath) "edk2-x86_64-code.fd")
        )
        foreach ($fw in $possibleFirmwares) {
            if ($fw -and (Test-Path $fw)) {
                $uefiFirmware = (Resolve-Path $fw).Path
                break
            }
        }
    }

    # 8. Sanity and Validation
    $isValid = $true
    $errors = @()

    if (-not $HostInfo.QemuPath) {
        $isValid = $false
        $errors += "QEMU binary not found. Place portable QEMU into 'backends\windows\qemu\' or add QEMU to PATH."
    }

    if (-not $selectedDisk) {
        $isValid = $false
        $errors += "No virtual disk found in '$VmDir'. Please place 'disk.qcow2' in this directory."
    }

    # Compute Safe Boundaries
    $safeMaxRamMB = [math]::Max(1024, $HostInfo.AvailableRamMB - 1024)
    $minRequiredRamMB = 1024
    $maxHostCores = [math]::Max(1, $HostInfo.LogicalCores)
    $minRequiredCores = 1

    $decision = [PSCustomObject]@{
        VmName            = $vmName
        VmDir             = $VmDir
        DiskPath          = $selectedDisk
        DiskFormat        = $diskFormat
        AllocatedRamMB    = $allocatedRam
        AllocatedCores    = $allocatedCores
        SafeMaxRamMB      = $safeMaxRamMB
        MinRequiredRamMB  = $minRequiredRamMB
        MaxHostCores      = $maxHostCores
        MinRequiredCores  = $minRequiredCores
        Accelerator       = $selectedAccel
        AccelWarning      = $accelWarning
        DisplayMode       = $display
        NetworkMode       = $network
        SshPort           = $sshPort
        UseUefi           = $uefi
        UefiFirmware      = $uefiFirmware
        QemuExe           = $HostInfo.QemuPath
        Arch              = $arch
        IsValid           = $isValid
        Errors            = $errors
    }

    return $decision
}

function Test-MemorySafety {
    param(
        [int]$RamMB,
        [PSCustomObject]$HostInfo
    )

    $warnings = @()
    $safeLimit = [math]::Max(1024, $HostInfo.AvailableRamMB - 1024)

    if ($RamMB -lt 1024) {
        $warnings += "Requested RAM (${RamMB} MB) is BELOW the minimum required limit (1024 MB). Guest Linux OS may crash with Out-Of-Memory (OOM) errors during boot."
    } elseif ($RamMB -lt 2048) {
        $warnings += "Requested RAM (${RamMB} MB) is low for desktop environments. Recommended minimum for desktop GUI is 2048 MB."
    }

    if ($RamMB -gt $HostInfo.TotalRamMB) {
        $warnings += "Requested RAM (${RamMB} MB) EXCEEDS total physical host RAM ($($HostInfo.TotalRamMB) MB)! VM cannot start."
    } elseif ($RamMB -gt $safeLimit) {
        $warnings += "Requested RAM (${RamMB} MB) EXCEEDS the safe free RAM limit (${safeLimit} MB). Programs already running on the host require memory. This may freeze or slow down the host system."
    }

    return $warnings
}

function Test-CpuSafety {
    param(
        [int]$Cores,
        [PSCustomObject]$HostInfo
    )

    $warnings = @()
    $maxCores = [math]::Max(1, $HostInfo.LogicalCores)

    if ($Cores -lt 1) {
        $warnings += "CPU cores must be at least 1."
    }
    if ($Cores -gt $maxCores) {
        $warnings += "Requested cores ($Cores) EXCEED total available host logical cores ($maxCores). Over-committing cores degrades performance."
    } elseif ($Cores -eq $maxCores -and $maxCores -gt 2) {
        $warnings += "Allocating 100% of host CPU cores ($Cores) may cause host desktop stuttering while the VM is under high load."
    }

    return $warnings
}

