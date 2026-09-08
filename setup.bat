@echo off
setlocal
cd /d "%~dp0"
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0scripts\windows\setup_installer.ps1" -SourceRoot "%~dp0"
endlocal
