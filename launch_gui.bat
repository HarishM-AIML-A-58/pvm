@echo off
if "%~1"=="vbs" goto :vbs
echo CreateObject("Wscript.Shell").Run """" ^& WScript.Arguments(0) ^& """ vbs", 0, False > "%temp%\hide_gui.vbs"
cscript //nologo "%temp%\hide_gui.vbs" "%~f0"
del "%temp%\hide_gui.vbs"
exit /b

:vbs
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0scripts\windows\gui_launcher.ps1"
endlocal
