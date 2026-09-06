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
        # 1. OS Details
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $hostInfo.OSName = $os.Caption
            $hostInfo.OSVersion = $os.Version
            $hostInfo.TotalRamMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
            $hostInfo.AvailableRamMB = [math]::Round($os.FreePhysicalMemory / 1024)
        }

        # 2. Processor Details
        $cpuList = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
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
        # Check systeminfo or ComputerSystem hypervisor flag
        $compSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($compSystem -and ($compSystem.HypervisorPresent -eq $true)) {
            $hostInfo.HypervisorPresent = $true
        }

        # 4. Check QEMU binary location
        $bundledQemu = Join-Path $RootDir "backends\windows\qemu\qemu-system-x86_64.exe"
        $qemuExe = ""

        if (Test-Path $bundledQemu) {
            $qemuExe = (Resolve-Path $bundledQemu).Path
        } else {
            $pathCmd = Get-Command "qemu-system-x86_64.exe" -ErrorAction SilentlyContinue
            if ($pathCmd) {
                $qemuExe = $pathCmd.Source
            }
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
