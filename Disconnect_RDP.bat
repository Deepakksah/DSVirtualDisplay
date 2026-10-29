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
    echo [INFO] Requesting Administrator Privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo ==========================================================
echo   Transferring RDP session to Virtual Display (Console)...
echo ==========================================================
echo.

:: 2. Get active session ID
set SESSION_ID=
for /f "tokens=3" %%i in ('query session ^| findstr /i ">"') do set SESSION_ID=%%i
if "%SESSION_ID%"=="" (
    for /f "tokens=2" %%i in ('query session ^| findstr /i ">"') do set SESSION_ID=%%i
)

if "%SESSION_ID%"=="" (
    echo [WARNING] Could not detect active session ID via query session. Trying PowerShell...
    for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-Process -Id (Get-CimInstance Win32_Process -Filter 'ProcessId=%PID%').ParentProcessId).SessionId"') do set SESSION_ID=%%i
)

echo   Active Session ID: %SESSION_ID%
echo   Redirecting session to Console (Virtual Display)...
echo.

if not "%SESSION_ID%"=="" (
    %windir%\System32\tscon.exe %SESSION_ID% /dest:console
) else (
    :: Fallback: try common session IDs 1 and 2
    %windir%\System32\tscon.exe 2 /dest:console 2>nul
    %windir%\System32\tscon.exe 1 /dest:console 2>nul
)

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Could not transfer session. Please make sure you are running as Administrator.
    pause
)
