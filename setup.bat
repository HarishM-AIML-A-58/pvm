@echo off
:: Portable VM First-Time Setup
:: Run this to install Portable VM onto your external drive.
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\windows\setup_installer.ps1" -SourceRoot "%~dp0"
