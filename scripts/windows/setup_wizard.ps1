<#
.SYNOPSIS
    GUI Setup Wizard for creating a new Virtual Machine on Windows.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$VmsDir,
    [Parameter(Mandatory = $true)]
    [PSCustomObject]$HostInfo
)

. (Join-Path $PSScriptRoot "setup_core.ps1")

$result = [PSCustomObject]@{
    ShouldCreate = $false
    VmName = ""
    IsoPath = ""
    DiskSizeGB = 64
}

$wizardForm = New-Object System.Windows.Forms.Form
$wizardForm.Text = "New Virtual Machine Setup"
$wizardForm.Size = New-Object System.Drawing.Size(500, 420)
$wizardForm.StartPosition = "CenterParent"
$wizardForm.FormBorderStyle = "FixedDialog"
$wizardForm.MaximizeBox = $false

$fontRegular = New-Object System.Drawing.Font("Segoe UI", 9)
$fontBold = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

# Name
$lblName = New-Object System.Windows.Forms.Label
$lblName.Text = "VM Name:"
$lblName.Location = New-Object System.Drawing.Point(20, 20)
$lblName.AutoSize = $true
$lblName.Font = $fontBold
$wizardForm.Controls.Add($lblName)

$txtName = New-Object System.Windows.Forms.TextBox
$txtName.Location = New-Object System.Drawing.Point(20, 45)
$txtName.Size = New-Object System.Drawing.Size(440, 25)
$wizardForm.Controls.Add($txtName)

# ISO Path
$lblIso = New-Object System.Windows.Forms.Label
$lblIso.Text = "Installation ISO File:"
$lblIso.Location = New-Object System.Drawing.Point(20, 90)
$lblIso.AutoSize = $true
$lblIso.Font = $fontBold
$wizardForm.Controls.Add($lblIso)

$txtIso = New-Object System.Windows.Forms.TextBox
$txtIso.Location = New-Object System.Drawing.Point(20, 115)
$txtIso.Size = New-Object System.Drawing.Size(340, 25)
$wizardForm.Controls.Add($txtIso)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(370, 114)
$btnBrowse.Size = New-Object System.Drawing.Size(90, 27)
$wizardForm.Controls.Add($btnBrowse)

$btnBrowse.add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "ISO Image Files (*.iso)|*.iso|All Files (*.*)|*.*"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtIso.Text = $dialog.FileName
        Validate-Wizard
    }
})

# Disk Size
$lblDisk = New-Object System.Windows.Forms.Label
$lblDisk.Text = "Root Disk Size (GB):"
$lblDisk.Location = New-Object System.Drawing.Point(20, 160)
$lblDisk.AutoSize = $true
$lblDisk.Font = $fontBold
$wizardForm.Controls.Add($lblDisk)

$numDisk = New-Object System.Windows.Forms.NumericUpDown
$numDisk.Minimum = 1
$numDisk.Maximum = 100000
$numDisk.Value = 64
$numDisk.Location = New-Object System.Drawing.Point(20, 185)
$numDisk.Size = New-Object System.Drawing.Size(120, 25)
$wizardForm.Controls.Add($numDisk)

# Status Label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 230)
$lblStatus.Size = New-Object System.Drawing.Size(440, 80)
$lblStatus.Font = $fontRegular
$wizardForm.Controls.Add($lblStatus)

# Buttons
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(250, 330)
$btnCancel.Size = New-Object System.Drawing.Size(100, 35)
$wizardForm.Controls.Add($btnCancel)
$btnCancel.add_Click({ $wizardForm.Close() })

$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "Create && Install"
$btnCreate.Location = New-Object System.Drawing.Point(360, 330)
$btnCreate.Size = New-Object System.Drawing.Size(100, 35)
$btnCreate.Enabled = $false
$btnCreate.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$btnCreate.ForeColor = [System.Drawing.Color]::White
$btnCreate.FlatStyle = "Flat"
$wizardForm.Controls.Add($btnCreate)

# Validation Logic
function Validate-Wizard {
    try {
        $isValid = $true
        $statusText = @()

        $currentName = ""
        if ($txtName -and $txtName.Text) { $currentName = $txtName.Text.Trim() }

        $currentIso = ""
        if ($txtIso -and $txtIso.Text) { $currentIso = $txtIso.Text.Trim() }

        $currentDiskGB = 64
        if ($numDisk) { $currentDiskGB = [int]$numDisk.Value }

        # Name check
        if ([string]::IsNullOrWhiteSpace($currentName)) {
            $isValid = $false
            $statusText += "VM Name cannot be empty."
        } else {
            $nameVal = Test-VmNameValid -VmName $currentName -VmsDir $VmsDir
            if (-not $nameVal.IsValid) { $isValid = $false; $statusText += $nameVal.Message }
        }

        # ISO check
        if ([string]::IsNullOrWhiteSpace($currentIso)) {
            $isValid = $false
            $statusText += "ISO path cannot be empty."
        } else {
            $isoVal = Test-IsoFileValid -IsoPath $currentIso
            if (-not $isoVal.IsValid) { $isValid = $false; $statusText += $isoVal.Message }
        }

        # Disk space check
        if ($HostInfo -and $HostInfo.SsdFreeSpaceGB) {
            $diskVal = Test-DiskSpaceAvailable -RequestedGB $currentDiskGB -HostInfo $HostInfo
            if (-not $diskVal.IsValid) {
                $isValid = $false
                $statusText += $diskVal.Message
            } elseif ($diskVal.Level -eq "WARNING") {
                $statusText += $diskVal.Message
            }
        }

        if ($isValid) {
            $lblStatus.Text = "Ready to create VM '$currentName'."
            $lblStatus.ForeColor = [System.Drawing.Color]::ForestGreen
            $btnCreate.Enabled = $true
        } else {
            $lblStatus.Text = ($statusText -join "`r`n")
            $lblStatus.ForeColor = [System.Drawing.Color]::Crimson
            $btnCreate.Enabled = $false
        }
    } catch {
        $lblStatus.Text = "Validation error: $_"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        $btnCreate.Enabled = $false
    }
}

$txtName.add_TextChanged({ Validate-Wizard })
$txtIso.add_TextChanged({ Validate-Wizard })
$numDisk.add_ValueChanged({ Validate-Wizard })

$btnCreate.add_Click({
    $btnCreate.Enabled = $false
    $btnCreate.Text = "Creating..."
    $lblStatus.Text = "Creating virtual disk. This may take a moment..."
    [System.Windows.Forms.Application]::DoEvents()

    $vmName = ($txtName.Text).Trim()
    $res = New-VmInstance -VmName $vmName -VmsDir $VmsDir -DiskSizeGB ([int]$numDisk.Value) -HostInfo $HostInfo

    if ($res.Success) {
        $result.ShouldCreate = $true
        $result.VmName = $vmName
        $result.IsoPath = ($txtIso.Text).Trim()
        $result.DiskSizeGB = [int]$numDisk.Value
        $wizardForm.Close()
    } else {
        [System.Windows.Forms.MessageBox]::Show($res.Message, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $btnCreate.Enabled = $true
        $btnCreate.Text = "Create && Install"
        Validate-Wizard
    }
})

Validate-Wizard
$wizardForm.ShowDialog() | Out-Null

return $result
