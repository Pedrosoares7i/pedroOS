@echo off
set "PEDRO_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PEDRO_ROOT%PEDRO.ps1"
