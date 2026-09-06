@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0scripts\windows\gui_launcher.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo GUI Launcher exited with code %ERRORLEVEL%.
    pause
)
endlocal
