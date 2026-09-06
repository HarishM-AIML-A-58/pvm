<#
.SYNOPSIS
    Terminal UI & formatting module for Portable VM Launcher.
#>

function Show-Banner {
    Write-Host ""
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host "               PORTABLE VIRTUAL MACHINE LAUNCHER                  " -ForegroundColor Yellow
    Write-Host "         Cross-Platform VM Environment from External SSD          " -ForegroundColor Gray
    Write-Host "  ================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-HostInfo {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$HostInfo
    )

    Write-Host "  [+] HOST HARDWARE & ENVIRONMENT" -ForegroundColor Green
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("  {0,-20} : {1}" -f "Host OS", "$($HostInfo.OSName) ($($HostInfo.Architecture))")
    Write-Host ("  {0,-20} : {1}" -f "CPU", "$($HostInfo.CPUName)")
    Write-Host ("  {0,-20} : {1}" -f "Cores", "$($HostInfo.LogicalCores) logical ($($HostInfo.PhysicalCores) physical)")
    Write-Host ("  {0,-20} : {1}" -f "RAM", "$([math]::Round($HostInfo.TotalRamMB / 1024, 1)) GB total / $([math]::Round($HostInfo.AvailableRamMB / 1024, 1)) GB free")

    $virtStatus = if ($HostInfo.VirtFirmwareEnabled) { "Enabled in BIOS/Firmware [OK]" } else { "Disabled or Unknown in BIOS" }
    $virtColor = if ($HostInfo.VirtFirmwareEnabled) { "Green" } else { "Yellow" }
    Write-Host ("  {0,-20} : " -f "Virtualization (BIOS)") -NoNewline
    Write-Host $virtStatus -ForegroundColor $virtColor

    $whpxStatus = if ($HostInfo.WhpxAvailable) { "Supported (WHPX / Hypervisor) [OK]" } else { "Not Available (Falling back to TCG)" }
    $whpxColor = if ($HostInfo.WhpxAvailable) { "Green" } else { "Yellow" }
    Write-Host ("  {0,-20} : " -f "Hypervisor Accel") -NoNewline
    Write-Host $whpxStatus -ForegroundColor $whpxColor

    $qemuStatus = if ($HostInfo.QemuPath) { "$($HostInfo.QemuVersion) ($($HostInfo.QemuPath))" } else { "NOT FOUND" }
    $qemuColor = if ($HostInfo.QemuPath) { "White" } else { "Red" }
    Write-Host ("  {0,-20} : " -f "QEMU Binary") -NoNewline
    Write-Host $qemuStatus -ForegroundColor $qemuColor

    if ($HostInfo.SsdFreeSpaceGB -gt 0) {
        Write-Host ("  {0,-20} : {1} GB" -f "SSD Free Space", $HostInfo.SsdFreeSpaceGB)
    }
    Write-Host ""
}

function Show-VmSelectionMenu {
    param(
        [Parameter(Mandatory = $true)]
        [array]$VmList
    )

    Write-Host "  [+] DETECTED VIRTUAL MACHINES" -ForegroundColor Green
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray

    if ($VmList.Count -eq 0) {
        Write-Host "  No VM directories found in 'vms/' folder." -ForegroundColor Yellow
        Write-Host "  Please create a folder under 'vms/' (e.g. 'vms/ubuntu/') with 'disk.qcow2'." -ForegroundColor Gray
        Write-Host ""
        return $null
    }

    for ($i = 0; $i -lt $VmList.Count; $i++) {
        $vm = $VmList[$i]
        $diskSizeStr = if ($vm.DiskSizeBytes -gt 0) {
            "{0:N2} GB" -f ($vm.DiskSizeBytes / 1GB)
        } else {
            "No disk file"
        }
        $num = "[{0}]" -f ($i + 1)
        Write-Host ("  {0,4} {1,-28} (Disk: {2})" -f $num, $vm.Name, $diskSizeStr) -ForegroundColor Cyan
    }
    Write-Host ""

    if ($VmList.Count -eq 1) {
        Write-Host "  -> Auto-selecting the only available VM: " -NoNewline -ForegroundColor Gray
        Write-Host "$($VmList[0].Name)" -ForegroundColor Yellow
        Write-Host ""
        return $VmList[0]
    }

    while ($true) {
        Write-Host "  Select VM number to launch (1-$($VmList.Count)) or 'Q' to quit: " -NoNewline -ForegroundColor Yellow
        $choice = Read-Host
        if ($choice -match "^[Qq]") {
            return $null
        }
        if ($choice -match "^\d+$") {
            $idx = [int]$choice - 1
            if ($idx -ge 0 -and $idx -lt $VmList.Count) {
                return $VmList[$idx]
            }
        }
        Write-Host "  Invalid choice. Please enter a number between 1 and $($VmList.Count)." -ForegroundColor Red
    }
}

function Show-DecisionSummary {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Decision,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]$HostInfo = $null
    )

    Write-Host "  [+] ALLOCATED VM CONFIGURATION" -ForegroundColor Green
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("  {0,-20} : {1}" -f "Selected VM", $Decision.VmName)
    Write-Host ("  {0,-20} : {1}" -f "Virtual Disk", $Decision.DiskPath)

    $ramLimitInfo = if ($Decision.SafeMaxRamMB) { " [Safe Range: $($Decision.MinRequiredRamMB) - $($Decision.SafeMaxRamMB) MB]" } else { "" }
    Write-Host ("  {0,-20} : {1} MB ({2:N1} GB){3}" -f "Allocated Memory", $Decision.AllocatedRamMB, ($Decision.AllocatedRamMB / 1024), $ramLimitInfo)

    $cpuLimitInfo = if ($Decision.MaxHostCores) { " [Available: 1 - $($Decision.MaxHostCores) Cores]" } else { "" }
    Write-Host ("  {0,-20} : {1} Cores{2}" -f "Allocated CPU", $Decision.AllocatedCores, $cpuLimitInfo)
    
    $accelLabel = switch ($Decision.Accelerator) {
        "whpx" { "WHPX (Windows Hypervisor Platform - Fast/Native)" }
        "kvm"  { "KVM (Kernel-based Virtual Machine - Native)" }
        "hvf"  { "HVF (Hypervisor.framework - Native)" }
        default { "TCG (Software Emulation - Slower)" }
    }
    $accelColor = if ($Decision.Accelerator -eq "tcg") { "Yellow" } else { "Green" }
    Write-Host ("  {0,-20} : " -f "Acceleration") -NoNewline
    Write-Host $accelLabel -ForegroundColor $accelColor

    if ($Decision.AccelWarning) {
        Write-Host "  [!] WARNING: " -NoNewline -ForegroundColor Yellow
        Write-Host $Decision.AccelWarning -ForegroundColor Yellow
    }

    Write-Host ("  {0,-20} : {1}" -f "Display Output", $Decision.DisplayMode)
    Write-Host ("  {0,-20} : {1} (Guest Port 22 -> Host Port {2})" -f "Network Mode", $Decision.NetworkMode, $Decision.SshPort)
    Write-Host ("  {0,-20} : {1}" -f "UEFI Boot", $(if ($Decision.UseUefi) { "Enabled" } else { "Disabled" }))
    Write-Host ""
}

function Invoke-InteractiveConfigMenu {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Decision,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$HostInfo
    )

    while ($true) {
        Write-Host "  ================================================================" -ForegroundColor Cyan
        Write-Host "                     VM CONFIGURATION REVIEW                      " -ForegroundColor Yellow
        Write-Host "  ================================================================" -ForegroundColor Cyan
        Write-Host "   [1] Modify Memory (RAM)       - Current: $($Decision.AllocatedRamMB) MB"
        Write-Host "   [2] Modify CPU Cores          - Current: $($Decision.AllocatedCores) Cores"
        Write-Host "   [3] Modify Display Backend    - Current: $($Decision.DisplayMode)"
        Write-Host "   [4] Modify SSH Port           - Current: $($Decision.SshPort)"
        Write-Host "   --------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "   [R / ENTER] Run / Launch Virtual Machine" -ForegroundColor Green
        Write-Host "   [Q]         Cancel and Exit" -ForegroundColor Red
        Write-Host "  ================================================================" -ForegroundColor Cyan
        Write-Host "  Choose an option to customize, or press [ENTER/R] to Run: " -NoNewline -ForegroundColor Yellow
        
        $choice = Read-Host
        $trimmed = $choice.Trim()

        if ($trimmed -eq "" -or $trimmed -match "^[Rr]$") {
            # User wants to run
            return $true
        }
        if ($trimmed -match "^[Qq]$") {
            # User cancels
            return $false
        }

        switch ($trimmed) {
            "1" {
                Write-Host ""
                Write-Host "  --- MODIFY MEMORY (RAM) ---" -ForegroundColor Cyan
                Write-Host "  Total Host RAM: $($HostInfo.TotalRamMB) MB | Available Free RAM: $($HostInfo.AvailableRamMB) MB" -ForegroundColor Gray
                Write-Host "  Safe Allocation Range: $($Decision.MinRequiredRamMB) MB to $($Decision.SafeMaxRamMB) MB" -ForegroundColor Gray
                Write-Host "  Enter new RAM amount in MB (or press Enter to keep $($Decision.AllocatedRamMB) MB): " -NoNewline -ForegroundColor Yellow
                $ramInput = Read-Host
                if ($ramInput -match "^\d+$") {
                    $newRam = [int]$ramInput
                    $warnings = Test-MemorySafety -RamMB $newRam -HostInfo $HostInfo
                    
                    if ($warnings.Count -gt 0) {
                        Write-Host ""
                        foreach ($w in $warnings) {
                            Write-Host "  [!] WARNING: $w" -ForegroundColor Yellow
                        }
                        Write-Host ""
                        Write-Host "  Do you still want to apply this value? (Y/N): " -NoNewline -ForegroundColor Yellow
                        $confirm = Read-Host
                        if ($confirm -match "^[Yy]$") {
                            $Decision.AllocatedRamMB = $newRam
                            Write-Host "  [+] Memory updated to $newRam MB." -ForegroundColor Green
                        } else {
                            Write-Host "  [i] Memory change discarded." -ForegroundColor Gray
                        }
                    } else {
                        $Decision.AllocatedRamMB = $newRam
                        Write-Host "  [+] Memory updated to $newRam MB." -ForegroundColor Green
                    }
                }
                Write-Host ""
            }

            "2" {
                Write-Host ""
                Write-Host "  --- MODIFY CPU CORES ---" -ForegroundColor Cyan
                Write-Host "  Host Logical Cores: $($HostInfo.LogicalCores) | Physical Cores: $($HostInfo.PhysicalCores)" -ForegroundColor Gray
                Write-Host "  Recommended: 1 to $([math]::Max(1, $HostInfo.LogicalCores / 2)) cores" -ForegroundColor Gray
                Write-Host "  Enter new core count (or press Enter to keep $($Decision.AllocatedCores) cores): " -NoNewline -ForegroundColor Yellow
                $coreInput = Read-Host
                if ($coreInput -match "^\d+$") {
                    $newCores = [int]$coreInput
                    $warnings = Test-CpuSafety -Cores $newCores -HostInfo $HostInfo

                    if ($warnings.Count -gt 0) {
                        Write-Host ""
                        foreach ($w in $warnings) {
                            Write-Host "  [!] WARNING: $w" -ForegroundColor Yellow
                        }
                        Write-Host ""
                        Write-Host "  Do you still want to apply this core count? (Y/N): " -NoNewline -ForegroundColor Yellow
                        $confirm = Read-Host
                        if ($confirm -match "^[Yy]$") {
                            $Decision.AllocatedCores = $newCores
                            Write-Host "  [+] CPU cores updated to $newCores." -ForegroundColor Green
                        } else {
                            Write-Host "  [i] Core change discarded." -ForegroundColor Gray
                        }
                    } else {
                        $Decision.AllocatedCores = $newCores
                        Write-Host "  [+] CPU cores updated to $newCores." -ForegroundColor Green
                    }
                }
                Write-Host ""
            }

            "3" {
                Write-Host ""
                Write-Host "  --- MODIFY DISPLAY BACKEND ---" -ForegroundColor Cyan
                Write-Host "  Available options: [1] sdl (window), [2] gtk, [3] vnc (headless), [4] default"
                Write-Host "  Select display option (1-4): " -NoNewline -ForegroundColor Yellow
                $dispChoice = Read-Host
                switch ($dispChoice.Trim()) {
                    "1" { $Decision.DisplayMode = "sdl"; Write-Host "  [+] Display set to SDL." -ForegroundColor Green }
                    "2" { $Decision.DisplayMode = "gtk"; Write-Host "  [+] Display set to GTK." -ForegroundColor Green }
                    "3" { $Decision.DisplayMode = "vnc"; Write-Host "  [+] Display set to VNC (127.0.0.1:0)." -ForegroundColor Green }
                    "4" { $Decision.DisplayMode = "default"; Write-Host "  [+] Display set to default." -ForegroundColor Green }
                }
                Write-Host ""
            }

            "4" {
                Write-Host ""
                Write-Host "  --- MODIFY SSH FORWARDING PORT ---" -ForegroundColor Cyan
                Write-Host "  Enter host port to forward to VM SSH port 22 (Current: $($Decision.SshPort)): " -NoNewline -ForegroundColor Yellow
                $portInput = Read-Host
                if ($portInput -match "^\d+$" -and [int]$portInput -ge 1024 -and [int]$portInput -le 65535) {
                    $Decision.SshPort = [int]$portInput
                    Write-Host "  [+] SSH forwarding port updated to $($Decision.SshPort)." -ForegroundColor Green
                } else {
                    Write-Host "  [!] Invalid port number (must be 1024-65535)." -ForegroundColor Red
                }
                Write-Host ""
            }

            default {
                Write-Host "  Invalid choice. Please select 1-4, R to run, or Q to cancel." -ForegroundColor Red
            }
        }

        # Show updated summary after every change
        Show-DecisionSummary -Decision $Decision -HostInfo $HostInfo
    }
}

