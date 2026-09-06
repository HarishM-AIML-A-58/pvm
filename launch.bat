@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\launcher.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Launcher exited with code %ERRORLEVEL%.
    pause
)
endlocal
