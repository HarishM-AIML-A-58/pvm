<#
.SYNOPSIS
    Centralized core logic for VM Setup Wizard (Windows).
.DESCRIPTION
    Provides validation and creation routines for new virtual machines.
#>

function Test-VmNameValid {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$VmName,
        [Parameter(Mandatory = $true)]
        [string]$VmsDir
    )

    $result = [PSCustomObject]@{ IsValid = $false; Message = "" }

    if ([string]::IsNullOrWhiteSpace($VmName)) {
        $result.Message = "VM Name cannot be empty."
        return $result
    }

    if ($VmName -match '[<>:"/\\|?*]') {
        $result.Message = "VM Name contains invalid characters."
        return $result
    }

    $targetDir = Join-Path $VmsDir $VmName
    if (Test-Path $targetDir) {
        $result.Message = "A VM with this name already exists."
        return $result
    }

    $result.IsValid = $true
    $result.Message = "[OK] Name is valid."
    return $result
}

function Test-IsoFileValid {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$IsoPath
    )

    $result = [PSCustomObject]@{ IsValid = $false; Message = ""; SizeGB = 0 }

    if ([string]::IsNullOrWhiteSpace($IsoPath)) {
        $result.Message = "ISO path cannot be empty."
        return $result
    }

    if (-not (Test-Path $IsoPath)) {
        $result.Message = "ISO file does not exist."
        return $result
    }

    $item = Get-Item $IsoPath
    if ($item.Extension -ne ".iso") {
        $result.Message = "Selected file is not an .iso file."
        return $result
    }

    $sizeGB = [math]::Round($item.Length / 1GB, 2)
    $result.IsValid = $true
    $result.SizeGB = $sizeGB
    $result.Message = "[OK] ISO found ($sizeGB GB)."
    return $result
}

function Test-DiskSpaceAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [int]$RequestedGB,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$HostInfo
    )

    $result = [PSCustomObject]@{ IsValid = $true; Level = "OK"; Message = "" }

    if ($RequestedGB -le 0) {
        $result.IsValid = $false
        $result.Level = "ERROR"
        $result.Message = "Disk size must be greater than 0."
        return $result
    }

    $freeGB = $HostInfo.SsdFreeSpaceGB

    if ($RequestedGB -ge $freeGB) {
        $result.IsValid = $false
        $result.Level = "ERROR"
        $result.Message = "Disk size exceeds available SSD free space ($freeGB GB)."
        return $result
    }

    if ($RequestedGB -gt ($freeGB * 0.5)) {
        $result.Level = "WARNING"
        $result.Message = "Warning: Requested disk size takes more than 50% of available SSD space ($freeGB GB)."
        return $result
    }

    $result.Message = "[OK] Space available. Fits in $freeGB GB free."
    return $result
}

function New-VmInstance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmName,
        [Parameter(Mandatory = $true)]
        [string]$VmsDir,
        [Parameter(Mandatory = $true)]
        [int]$DiskSizeGB,
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$HostInfo
    )

    $result = [PSCustomObject]@{ Success = $false; Message = ""; VmDir = "" }

    try {
        $targetDir = Join-Path $VmsDir $VmName
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $qemuExe = $HostInfo.QemuPath
        $qemuDir = Split-Path $qemuExe -Parent
        $qemuImgExe = Join-Path $qemuDir "qemu-img.exe"

        if (-not (Test-Path $qemuImgExe)) {
            # Try finding it in path
            $pathCmd = Get-Command "qemu-img.exe" -ErrorAction SilentlyContinue
            if ($pathCmd) {
                $qemuImgExe = $pathCmd.Source
            } else {
                throw "qemu-img.exe not found."
            }
        }

        $diskPath = Join-Path $targetDir "disk.qcow2"
        $createArgs = @("create", "-f", "qcow2", "`"$diskPath`"", "${DiskSizeGB}G")
        $procArgs = $createArgs -join " "

        $process = Start-Process -FilePath $qemuImgExe -ArgumentList $procArgs -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "qemu-img failed with exit code $($process.ExitCode)"
        }

        $confPath = Join-Path $targetDir "vm.conf"
        $confContent = @"
# VM Configuration Overrides
name=$VmName
display=sdl
network=nat
uefi=false
"@
        Set-Content -Path $confPath -Value $confContent

        $result.Success = $true
        $result.VmDir = $targetDir
        $result.Message = "VM created successfully."
    } catch {
        $result.Message = "Failed to create VM: $_"
    }

    return $result
}
