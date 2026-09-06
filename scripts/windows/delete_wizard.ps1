<#
.SYNOPSIS
    GUI Delete Wizard for removing a Virtual Machine on Windows.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$VmName,
    [Parameter(Mandatory = $true)]
    [string]$VmsDir
)

$targetDir = Join-Path $VmsDir $VmName

$result = [PSCustomObject]@{
    Deleted = $false
}

if (-not (Test-Path $targetDir)) {
    [System.Windows.Forms.MessageBox]::Show("VM '$VmName' not found.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    return $result
}

$wizardForm = New-Object System.Windows.Forms.Form
$wizardForm.Text = "Delete Virtual Machine"
$wizardForm.Size = New-Object System.Drawing.Size(500, 420)
$wizardForm.StartPosition = "CenterParent"
$wizardForm.FormBorderStyle = "FixedDialog"
$wizardForm.MaximizeBox = $false

$fontRegular = New-Object System.Drawing.Font("Segoe UI", 9)
$fontBold = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

# Warning Label
$lblWarn = New-Object System.Windows.Forms.Label
$lblWarn.Text = "WARNING: You are about to permanently delete the VM:`r`n'$VmName'`r`n`r`nThis action cannot be undone. All data will be lost."
$lblWarn.Location = New-Object System.Drawing.Point(20, 20)
$lblWarn.Size = New-Object System.Drawing.Size(440, 60)
$lblWarn.Font = $fontBold
$lblWarn.ForeColor = [System.Drawing.Color]::Crimson
$wizardForm.Controls.Add($lblWarn)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 90)
$progressBar.Size = New-Object System.Drawing.Size(440, 25)
$progressBar.Style = "Blocks"
$wizardForm.Controls.Add($progressBar)

# ListBox for file details
$lblFiles = New-Object System.Windows.Forms.Label
$lblFiles.Text = "Deletion Progress:"
$lblFiles.Location = New-Object System.Drawing.Point(20, 130)
$lblFiles.AutoSize = $true
$lblFiles.Font = $fontBold
$wizardForm.Controls.Add($lblFiles)

$lstFiles = New-Object System.Windows.Forms.ListBox
$lstFiles.Location = New-Object System.Drawing.Point(20, 155)
$lstFiles.Size = New-Object System.Drawing.Size(440, 160)
$lstFiles.Font = $fontRegular
$lstFiles.BackColor = [System.Drawing.Color]::Black
$lstFiles.ForeColor = [System.Drawing.Color]::LimeGreen
$wizardForm.Controls.Add($lstFiles)

# Buttons
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(250, 330)
$btnCancel.Size = New-Object System.Drawing.Size(100, 35)
$wizardForm.Controls.Add($btnCancel)
$btnCancel.add_Click({ $wizardForm.Close() })

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete VM"
$btnDelete.Location = New-Object System.Drawing.Point(360, 330)
$btnDelete.Size = New-Object System.Drawing.Size(100, 35)
$btnDelete.BackColor = [System.Drawing.Color]::Crimson
$btnDelete.ForeColor = [System.Drawing.Color]::White
$btnDelete.FlatStyle = "Flat"
$wizardForm.Controls.Add($btnDelete)

$btnDelete.add_Click({
    $btnDelete.Enabled = $false
    $btnCancel.Enabled = $false
    
    $lstFiles.Items.Add("[*] Analyzing directory...") | Out-Null
    [System.Windows.Forms.Application]::DoEvents()
    
    $files = Get-ChildItem -Path $targetDir -Recurse -File
    $progressBar.Maximum = $files.Count + 1
    $progressBar.Value = 0
    
    $i = 0
    foreach ($f in $files) {
        $lstFiles.Items.Add("[-] Deleting: $($f.Name)") | Out-Null
        $lstFiles.TopIndex = $lstFiles.Items.Count - 1
        
        try {
            Remove-Item -Path $f.FullName -Force -ErrorAction Stop
        } catch {
            $lstFiles.Items.Add("[!] Error deleting $($f.Name)") | Out-Null
        }
        
        $i++
        $progressBar.Value = $i
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 20 # Slight delay so user can see it
    }
    
    $lstFiles.Items.Add("[*] Removing directory...") | Out-Null
    $lstFiles.TopIndex = $lstFiles.Items.Count - 1
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        Remove-Item -Path $targetDir -Recurse -Force -ErrorAction Stop
        $progressBar.Value = $progressBar.Maximum
        $lstFiles.Items.Add("[+] Successfully deleted VM '$VmName'.") | Out-Null
        $result.Deleted = $true
    } catch {
        $lstFiles.Items.Add("[!] Error removing directory.") | Out-Null
    }
    
    $lstFiles.TopIndex = $lstFiles.Items.Count - 1
    $btnCancel.Text = "Close"
    $btnCancel.Enabled = $true
})

$wizardForm.ShowDialog() | Out-Null

return $result
