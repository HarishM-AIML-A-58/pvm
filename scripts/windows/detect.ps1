<#
.SYNOPSIS
    Host hardware and virtualization capability detector for Windows.
.DESCRIPTION
    Collects CPU, RAM, OS, Virtualization (WHPX / BIOS), and QEMU availability.
#>

function Get-HostInformation {
    param(
        [Parameter(Mandatory = $false)]
        [string]$RootDir = $PSScriptRoot
    )

    $hostInfo = [PSCustomObject]@{
        OSName               = "Unknown Windows"
        OSVersion            = ""
        Architecture         = $env:PROCESSOR_ARCHITECTURE
        CPUName              = "Unknown CPU"
        PhysicalCores        = 1
        LogicalCores         = 1
        TotalRamMB           = 2048
        AvailableRamMB       = 1024
        VirtFirmwareEnabled  = $false
        HypervisorPresent    = $false
        WhpxAvailable        = $false
        QemuPath             = ""
        QemuVersion          = "Not Found"
        QemuAccelerators     = @()
        SsdFreeSpaceGB       = 0
    }

    try {
        # 1. OS Details — use WMI with CIM fallback for all Win10 versions
        $os = $null
        try { $os = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {}
        if (-not $os) { try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {} }
        if ($os) {
            $hostInfo.OSName = $os.Caption
            $hostInfo.OSVersion = $os.Version
            $hostInfo.TotalRamMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
            $hostInfo.AvailableRamMB = [math]::Round($os.FreePhysicalMemory / 1024)
        }

        # 2. Processor Details — WMI with CIM fallback
        $cpuList = $null
        try { $cpuList = Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue } catch {}
        if (-not $cpuList) { try { $cpuList = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue } catch {} }
        if ($cpuList) {
            $primaryCpu = $cpuList | Select-Object -First 1
            $hostInfo.CPUName = ($primaryCpu.Name -replace '\s+', ' ').Trim()
            
            $totalPhysicalCores = ($cpuList | Measure-Object -Property NumberOfCores -Sum).Sum
            $totalLogicalCores = ($cpuList | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum

            $hostInfo.PhysicalCores = if ($totalPhysicalCores) { $totalPhysicalCores } else { 1 }
            $hostInfo.LogicalCores = if ($totalLogicalCores) { $totalLogicalCores } else { [System.Environment]::ProcessorCount }

            if ($primaryCpu.VirtualizationFirmwareEnabled -ne $null) {
                $hostInfo.VirtFirmwareEnabled = [bool]$primaryCpu.VirtualizationFirmwareEnabled
            }
        }

        # 3. Hypervisor / WHPX Detection
        $compSystem = $null
        try { $compSystem = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue } catch {}
        if (-not $compSystem) { try { $compSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue } catch {} }
        if ($compSystem -and ($compSystem.HypervisorPresent -eq $true)) {
            $hostInfo.HypervisorPresent = $true
        }

        # 4. Resolve architecture-aware QEMU binary name
        #    Priority: config.json arch -> $env:PROCESSOR_ARCHITECTURE mapping
        $configArch = "x86_64"
        $configFile = Join-Path $RootDir "config.json"
        if (Test-Path $configFile) {
            try {
                $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
                if ($cfg.vm_defaults.arch) { $configArch = $cfg.vm_defaults.arch }
            } catch {}
        }
        # Override from detected host arch if config says x86_64 but we're on ARM
        $rawHostArch = $env:PROCESSOR_ARCHITECTURE
        if ($rawHostArch -eq "ARM64" -and $configArch -eq "x86_64") {
            $configArch = "aarch64"   # prefer native
        }
        $qemuBinaryName = "qemu-system-$configArch.exe"

        # 5. Check QEMU binary location (arch-aware)
        $bundledQemu = Join-Path $RootDir "backends\windows\qemu\$qemuBinaryName"
        $qemuExe = ""

        if (Test-Path $bundledQemu) {
            $qemuExe = (Resolve-Path $bundledQemu).Path
        } else {
            # Scan backends folder for any matching arch binary
            $qemuDir = Join-Path $RootDir "backends\windows\qemu"
            if (Test-Path $qemuDir) {
                $found = Get-ChildItem -Path $qemuDir -Filter $qemuBinaryName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $qemuExe = $found.FullName }
            }
        }
        # Final fallback: PATH
        if (-not $qemuExe) {
            $pathCmd = Get-Command $qemuBinaryName -ErrorAction SilentlyContinue
            if ($pathCmd) { $qemuExe = $pathCmd.Source }
        }

        if ($qemuExe -and (Test-Path $qemuExe)) {
            $hostInfo.QemuPath = $qemuExe
            
            # Query QEMU version
            $verOutput = (& $qemuExe --version 2>&1) -join "`n"
            if ($verOutput -match "version\s+([0-9\.]+)") {
                $hostInfo.QemuVersion = $Matches[1]
            }

            # Query QEMU supported accelerators
            $accelOutput = & $qemuExe -accel help 2>&1
            $accels = @()
            foreach ($line in ($accelOutput -split "`r?`n")) {
                $trimmed = $line.Trim()
                if ($trimmed -and -not ($trimmed.StartsWith("Accelerators") -or $trimmed.StartsWith("Supported"))) {
                    $accels += $trimmed
                }
            }
            $hostInfo.QemuAccelerators = $accels

            if ($accels -contains "whpx" -or ($hostInfo.VirtFirmwareEnabled -and $accels -contains "whpx")) {
                $hostInfo.WhpxAvailable = $true
            }
        }

        # 5. SSD / Drive Free Space
        $driveLetter = (Split-Path -Qualifier (Resolve-Path $RootDir).Path) -replace ':', ''
        if ($driveLetter) {
            $drive = Get-PSDrive -Name $driveLetter -PSProvider FileSystem -ErrorAction SilentlyContinue
            if ($drive) {
                $hostInfo.SsdFreeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
            }
        }
    }
    catch {
        Write-Warning "Detection encountered an issue: $_"
    }

    return $hostInfo
}

# Allow direct script execution for standalone testing
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Path) {
    $info = Get-HostInformation -RootDir (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
    $info | Format-List
}
