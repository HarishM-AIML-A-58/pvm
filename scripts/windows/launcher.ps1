<#
.SYNOPSIS
    Main Windows Orchestrator for the Portable VM Launcher.
.DESCRIPTION
    Integrates host detection, multi-VM selection, resource decision, command synthesis, and execution.
#>

param(
    [switch]$DetectOnly,
    [switch]$DryRun,
    [switch]$ListVMs,
    [switch]$Setup,
    [switch]$Delete,
    [string]$VmName = "",
    [switch]$NoPrompt
)

# Root of the SSD (two levels up from scripts\windows)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path (Split-Path $ScriptDir -Parent) -Parent

# Dot-source helper modules
. (Join-Path $ScriptDir "detect.ps1")
. (Join-Path $ScriptDir "decide.ps1")
. (Join-Path $ScriptDir "build_command.ps1")
. (Join-Path $ScriptDir "display.ps1")

Show-Banner

# 1. Host Detection
$hostInfo = Get-HostInformation -RootDir $RootDir
Show-HostInfo -HostInfo $hostInfo

if ($DetectOnly) {
    Write-Host "  [i] Detection completed (-DetectOnly flag specified)." -ForegroundColor Cyan
    exit 0
}

# Setup Mode Logic
if ($Setup) {
    . (Join-Path $ScriptDir "setup_core.ps1")
    Write-Host "`n  [+] NEW VM SETUP" -ForegroundColor Green
    $vmsDir = Join-Path $RootDir "vms"
    
    $vmNameSetup = Read-Host "  VM Name"
    $val = Test-VmNameValid -VmName $vmNameSetup -VmsDir $vmsDir
    if (-not $val.IsValid) { Write-Host "  [!] $($val.Message)" -ForegroundColor Red; exit 1 }

    $isoPath = Read-Host "  ISO File Path (e.g. C:\path\to\ubuntu.iso)"
    $valIso = Test-IsoFileValid -IsoPath $isoPath
    if (-not $valIso.IsValid) { Write-Host "  [!] $($valIso.Message)" -ForegroundColor Red; exit 1 }

    $diskSizeStr = Read-Host "  Root Disk Size (GB) [64]"
    if ([string]::IsNullOrWhiteSpace($diskSizeStr)) { $diskSizeStr = "64" }
    $diskSizeSetup = [int]$diskSizeStr

    $valSpace = Test-DiskSpaceAvailable -RequestedGB $diskSizeSetup -HostInfo $hostInfo
    if (-not $valSpace.IsValid) { Write-Host "  [!] $($valSpace.Message)" -ForegroundColor Red; exit 1 }
    if ($valSpace.Level -eq "WARNING") { Write-Host "  [!] $($valSpace.Message)" -ForegroundColor Yellow }

    Write-Host "  Creating VM..." -NoNewline
    $res = New-VmInstance -VmName $vmNameSetup -VmsDir $vmsDir -DiskSizeGB $diskSizeSetup -HostInfo $hostInfo
    if (-not $res.Success) {
        Write-Host " Failed." -ForegroundColor Red
        Write-Host "  [!] $($res.Message)" -ForegroundColor Red
        exit 1
    }
    Write-Host " Done." -ForegroundColor Green

    # Launch it immediately
    $selectedVmSetup = [PSCustomObject]@{ Name = $vmNameSetup; FullPath = $res.VmDir; DiskSizeBytes = 0 }
    $decisionSetup = Invoke-DecisionEngine -HostInfo $hostInfo -RootDir $RootDir -VmDir $res.VmDir
    $decisionSetup | Add-Member -NotePropertyName IsoPath -NotePropertyValue $isoPath -Force
    
    $cmdSpecSetup = Build-QemuCommand -Decision $decisionSetup
    Write-Host "  [*] Launching Installer for '$vmNameSetup'..." -ForegroundColor Green
    try {
        $processSetup = Start-Process -FilePath $cmdSpecSetup.Executable -ArgumentList $cmdSpecSetup.Arguments -Wait -PassThru -NoNewWindow
        exit $processSetup.ExitCode
    } catch {
        Write-Host "  [X] Failed to launch QEMU: $_" -ForegroundColor Red
        exit 1
    }
}

# Delete Mode Logic
if ($Delete) {
    if (-not $VmName) {
        Write-Host "  [!] Please specify the VM to delete using -VmName <name>" -ForegroundColor Red
        exit 1
    }

    $vmsDir = Join-Path $RootDir "vms"
    $targetDir = Join-Path $vmsDir $VmName

    if (-not (Test-Path $targetDir)) {
        Write-Host "  [!] VM '$VmName' not found." -ForegroundColor Red
        exit 1
    }

    Write-Host "`n  [-] DELETE VM" -ForegroundColor Red
    Write-Host "  WARNING: You are about to permanently delete the VM '$VmName'." -ForegroundColor Yellow
    Write-Host "  All data will be lost. This action cannot be undone." -ForegroundColor Yellow
    
    if (-not $NoPrompt) {
        $confirm = Read-Host "  Are you sure? (y/N)"
        if ($confirm -notmatch "^y(es)?`$") {
            Write-Host "  Aborted." -ForegroundColor Cyan
            exit 0
        }
    }

    $files = Get-ChildItem -Path $targetDir -Recurse -File
    $total = $files.Count + 1
    $i = 0

    foreach ($f in $files) {
        $i++
        Write-Progress -Activity "Deleting VM '$VmName'" -Status "Removing: $($f.Name)" -PercentComplete (($i / $total) * 100)
        Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
    }

    Write-Progress -Activity "Deleting VM '$VmName'" -Status "Removing directory..." -PercentComplete (($total / $total) * 100)
    Remove-Item -Path $targetDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Progress -Activity "Deleting VM '$VmName'" -Completed

    Write-Host "  [+] Successfully deleted VM '$VmName'." -ForegroundColor Green
    exit 0
}

# 2. Discover Virtual Machines in vms/
$vmsDir = Join-Path $RootDir "vms"
$vmList = @()

if (Test-Path $vmsDir) {
    $subDirs = Get-ChildItem -Path $vmsDir -Directory
    foreach ($dir in $subDirs) {
        $diskSize = 0
        $diskCandidates = @("disk.qcow2", "vm.qcow2", "disk.raw", "disk.img")
        foreach ($cand in $diskCandidates) {
            $candPath = Join-Path $dir.FullName $cand
            if (Test-Path $candPath) {
                $diskItem = Get-Item $candPath
                $diskSize = $diskItem.Length
                break
            }
        }

        $vmList += [PSCustomObject]@{
            Name          = $dir.Name
            FullPath      = $dir.FullName
            DiskSizeBytes = $diskSize
        }
    }
}

if ($ListVMs) {
    Show-VmSelectionMenu -VmList $vmList | Out-Null
    exit 0
}

# 3. Select VM
$selectedVm = $null
if ($VmName) {
    $selectedVm = $vmList | Where-Object { $_.Name -eq $VmName } | Select-Object -First 1
    if (-not $selectedVm) {
        Write-Host "  [!] Error: VM '$VmName' not found in '$vmsDir'." -ForegroundColor Red
        exit 1
    }
} else {
    $selectedVm = Show-VmSelectionMenu -VmList $vmList
    if (-not $selectedVm) {
        Write-Host "  [i] Exiting launcher." -ForegroundColor Gray
        exit 0
    }
}

# 4. Decision Engine
$decision = Invoke-DecisionEngine -HostInfo $hostInfo -RootDir $RootDir -VmDir $selectedVm.FullPath
Show-DecisionSummary -Decision $decision -HostInfo $hostInfo

if (-not $decision.IsValid) {
    Write-Host "  [X] CANNOT LAUNCH VM DUE TO CONFIGURATION ERRORS:" -ForegroundColor Red
    foreach ($err in $decision.Errors) {
        Write-Host "      - $err" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}

# 5. Interactive Configuration Review (if not in non-interactive/dry-run mode)
if (-not $NoPrompt -and -not $DryRun) {
    $proceed = Invoke-InteractiveConfigMenu -Decision $decision -HostInfo $hostInfo
    if (-not $proceed) {
        Write-Host "  [i] Launch cancelled by user." -ForegroundColor Gray
        exit 0
    }
}

# 6. Build QEMU Command Line
$cmdSpec = Build-QemuCommand -Decision $decision

Write-Host "  [+] GENERATED QEMU COMMAND" -ForegroundColor Green
Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  $($cmdSpec.CommandLine)" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Host "  [i] Dry-run completed (-DryRun flag specified). VM will not be launched." -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host "  [*] Launching Virtual Machine '$($decision.VmName)'..." -ForegroundColor Green
Write-Host ""

# 7. Execute QEMU process
try {
    # Start QEMU and redirect stderr to $null to suppress harmless warnings (like xsave state)
    $process = Start-Process -FilePath $cmdSpec.Executable -ArgumentList $cmdSpec.Arguments -PassThru -NoNewWindow -RedirectStandardError "$env:TEMP\qemu_err.log"
    $process.WaitForExit()
    Write-Host "  [+] Virtual Machine session terminated with exit code $($process.ExitCode)." -ForegroundColor Cyan
    exit $process.ExitCode
} catch {
    Write-Host "  [X] Failed to launch QEMU: $_" -ForegroundColor Red
    exit 1
}
