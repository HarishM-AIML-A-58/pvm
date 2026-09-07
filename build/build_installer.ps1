<#
.SYNOPSIS
    Packages the Portable VM project into a single self-extracting PortableVM_Setup.bat
.DESCRIPTION
    Collects all project files, zips them, encodes the zip to Base64, and embeds it
    into a batch file. The batch file extracts itself to %TEMP% and runs the setup.
.EXAMPLE
    .\build\build_installer.ps1
#>

param(
    [string]$OutputBat = "PortableVM_Setup.bat",
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

Write-Host "=== Portable VM Installer Builder ===" -ForegroundColor Cyan
Write-Host "Project root : $ProjectRoot"
Write-Host "Output       : $OutputBat"
Write-Host ""

$filesToPack = @()
$includeItems = @(
    "scripts", "config.json", "launch.bat", "launch.sh",
    "launch_gui.bat", "launch_gui.sh", "README.md", ".gitignore"
)

Write-Host "[1/4] Collecting project files..." -ForegroundColor Yellow

foreach ($item in $includeItems) {
    $fullPath = Join-Path $ProjectRoot $item
    if (Test-Path $fullPath) {
        if ((Get-Item $fullPath).PSIsContainer) {
            $files = Get-ChildItem -Path $fullPath -Recurse -File | Where-Object { $_.Name -notmatch "^\.git" }
            $filesToPack += $files | ForEach-Object { $_.FullName }
        } else {
            $filesToPack += $fullPath
        }
    }
}

Write-Host "  Found $($filesToPack.Count) files to pack."

$stagingDir = Join-Path $env:TEMP "PortableVM_Build_$(Get-Random)"
Write-Host "[2/4] Staging files to: $stagingDir" -ForegroundColor Yellow

if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

foreach ($file in $filesToPack) {
    $relativePath = $file.Substring($ProjectRoot.Length).TrimStart("\")
    $destPath = Join-Path $stagingDir $relativePath
    $destDir = Split-Path $destPath -Parent
    if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
    Copy-Item -Path $file -Destination $destPath -Force
}

@("vms", "backends\windows\qemu") | ForEach-Object {
    $d = Join-Path $stagingDir $_
    if (-not (Test-Path $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null }
    Set-Content -Path (Join-Path $d ".keep") -Value ""
}

Write-Host "[3/4] Zipping payload..." -ForegroundColor Yellow
$payloadZip = Join-Path $env:TEMP "PortableVM_Payload.zip"
if (Test-Path $payloadZip) { Remove-Item $payloadZip -Force }
Compress-Archive -Path "$stagingDir\*" -DestinationPath $payloadZip -Force

Write-Host "[4/4] Generating $OutputBat..." -ForegroundColor Yellow
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($payloadZip))
$outputBatPath = Join-Path $ProjectRoot $OutputBat

$batContent = @"
@echo off
if "%~1"=="vbs" goto :vbs
echo CreateObject("Wscript.Shell").Run """" ^& WScript.Arguments(0) ^& """ vbs", 0, False > "%temp%\hide_setup.vbs"
cscript //nologo "%temp%\hide_setup.vbs" "%~f0"
del "%temp%\hide_setup.vbs"
exit /b

:vbs
setlocal
set "TEMP_DIR=%TEMP%\PortableVM_Setup_%RANDOM%"
mkdir "%TEMP_DIR%"
set "ZIP_FILE=%TEMP_DIR%\payload.zip"
set "B64_FILE=%TEMP_DIR%\payload.b64"

(
"@
# Write the base64 data in chunks
$chunkSize = 80
for ($i = 0; $i -lt $base64.Length; $i += $chunkSize) {
    $len = [math]::Min($chunkSize, $base64.Length - $i)
    $batContent += "echo " + $base64.Substring($i, $len) + "`r`n"
}

$batContent += @"
) > "%B64_FILE%"

certutil -decode "%B64_FILE%" "%ZIP_FILE%" >nul 2>&1
powershell -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%ZIP_FILE%', '%TEMP_DIR%')"

powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%TEMP_DIR%\scripts\windows\setup_installer.ps1" -SourceRoot "%TEMP_DIR%" -InstallerDir "%~dp0"
rmdir /s /q "%TEMP_DIR%"
exit /b 0
"@

Set-Content -Path $outputBatPath -Value $batContent -Encoding Ascii

$sizeMB = [math]::Round((Get-Item $outputBatPath).Length / 1MB, 2)
Write-Host "=== Build Successful! ===" -ForegroundColor Green
Write-Host "  Output : $outputBatPath"
Write-Host "  Size   : $sizeMB MB"

Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $payloadZip -Force -ErrorAction SilentlyContinue
