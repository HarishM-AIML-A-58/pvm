<#
.SYNOPSIS
    Packages the Portable VM project into a clean .exe using Inno Setup.
.DESCRIPTION
    Invokes Inno Setup Compiler (ISCC.exe) to bundle the project into a professional,
    single-file .exe installer wrapper.
.EXAMPLE
    .\build\build_installer.ps1
#>

param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

Write-Host "=== Portable VM Inno Setup Packager ===" -ForegroundColor Cyan
Write-Host "Project root : $ProjectRoot"
Write-Host ""

$isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccPath)) {
    Write-Host "[!] Inno Setup Compiler not found at $isccPath" -ForegroundColor Red
    Write-Host "Please install Inno Setup 6 to compile the .exe installer." -ForegroundColor Yellow
    exit 1
}

$issFile = Join-Path $ProjectRoot "build\PortableVM.iss"
if (-not (Test-Path $issFile)) {
    Write-Host "[!] Inno Setup script not found at $issFile" -ForegroundColor Red
    exit 1
}

Write-Host "[1/2] Compiling PortableVM.iss..." -ForegroundColor Yellow

$process = Start-Process -FilePath $isccPath -ArgumentList "`"$issFile`"" -Wait -NoNewWindow -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "[2/2] Build Successful!" -ForegroundColor Green
    $outputExe = Join-Path $ProjectRoot "PortableVM_Setup.exe"
    if (Test-Path $outputExe) {
        $sizeMB = [math]::Round((Get-Item $outputExe).Length / 1MB, 2)
        Write-Host "  Output : $outputExe"
        Write-Host "  Size   : $sizeMB MB"
    }
} else {
    Write-Host "[!] Build Failed with exit code $($process.ExitCode)" -ForegroundColor Red
}
