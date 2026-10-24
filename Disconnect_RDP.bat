@echo off
:: ==============================================================================
:: Disconnect_RDP.bat - Safely disconnect RDP without locking the screen
::
:: Keeps the screen rendering LIVE on the Virtual Display so that TeamViewer,
:: AnyDesk, or VNC NEVER show a black screen or "Screen cannot be captured".
:: ==============================================================================

echo.
echo ==========================================================
echo   Transferring RDP session to Virtual Display (Console)...
echo ==========================================================
echo.

:: Automatically detect the current active session ID and redirect to console
powershell -NoProfile -Command "
    $sessionId = (Get-Process -Id $PID).SessionId
    Write-Host \"Active Session ID: $sessionId\" -ForegroundColor Cyan
    Write-Host \"Redirecting to Console...\" -ForegroundColor Green
    & \"$env:windir\System32\tscon.exe\" $sessionId /dest:console
"

if %errorlevel% neq 0 (
    echo.
    echo [TIP] If access was denied, right-click this file and select 'Run as administrator'.
    pause
)
