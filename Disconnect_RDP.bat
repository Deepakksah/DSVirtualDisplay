@echo off
:: ==============================================================================
:: Disconnect_RDP.bat - Safely disconnect RDP without locking the screen
::
:: Keeps the screen rendering LIVE on the Virtual Display so that TeamViewer,
:: AnyDesk, or VNC NEVER show a black screen or "Screen cannot be captured".
:: ==============================================================================

:: 1. Auto-elevate to Administrator if not already elevated
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo ==========================================================
echo   Transferring RDP session to Virtual Display (Console)...
echo ==========================================================
echo.

:: 2. Transfer session to console
powershell -NoProfile -Command "
    $sessionId = (Get-Process -Id $PID).SessionId
    Write-Host \"  Active Session ID: $sessionId\" -ForegroundColor Cyan
    Write-Host \"  Transferring to Console (Virtual Monitor)...\" -ForegroundColor Green
    & \"$env:windir\System32\tscon.exe\" $sessionId /dest:console
"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Could not transfer session.
    pause
)
