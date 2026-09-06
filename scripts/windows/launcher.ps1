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
    $process = Start-Process -FilePath $cmdSpec.Executable -ArgumentList $cmdSpec.Arguments -Wait -PassThru -NoNewWindow
    Write-Host "  [+] Virtual Machine session terminated with exit code $($process.ExitCode)." -ForegroundColor Cyan
} catch {
    Write-Host "  [X] Failed to launch QEMU: $_" -ForegroundColor Red
}

