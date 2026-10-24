@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo ==========================================================
echo   DSVirtualDisplay - System Diagnostic & Status Check
echo ==========================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check_Status.ps1"

set "LOGFILE=%~dp0server_diagnostic.txt"
if not exist "%LOGFILE%" set "LOGFILE=C:\IddSampleDriver\server_diagnostic.txt"
if exist "%LOGFILE%" (
    start notepad.exe "%LOGFILE%" 2>nul
)

echo.
echo ==========================================================
echo   Diagnostic complete! Output displayed above and saved.
echo ==========================================================
echo Press any key to exit...
pause >nul
