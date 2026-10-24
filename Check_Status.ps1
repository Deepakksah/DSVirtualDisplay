# ==============================================================================
# Check_Status.ps1 - Comprehensive System Diagnostics for Virtual Display
# ==============================================================================
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logLines = [System.Collections.Generic.List[string]]::new()

function Add-Log([string]$text = "") {
    $script:logLines.Add($text)
}

function Print-Header([string]$title) {
    $sep = "================================================================"
    Write-Host "`n$sep" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "$sep" -ForegroundColor Cyan
    Add-Log ""
    Add-Log $sep
    Add-Log "  $title"
    Add-Log $sep
}

function Print-Result([string]$name, [string]$status, [string]$color) {
    Write-Host ("  {0,-35} : " -f $name) -NoNewline
    Write-Host $status -ForegroundColor $color
    Add-Log ("  {0,-35} : {1}" -f $name, $status)
}

Add-Log "================================================================"
Add-Log "  DSVirtualDisplay - System Diagnostic Report"
Add-Log "  Timestamp : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Log "  Computer  : $env:COMPUTERNAME"
Add-Log "  User      : $env:USERNAME"
Add-Log "  OS        : $((Get-CimInstance Win32_OperatingSystem).Caption) ($((Get-CimInstance Win32_OperatingSystem).OSArchitecture))"
Add-Log "================================================================"

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  DSVirtualDisplay - System Diagnostic Report" -ForegroundColor Cyan
Write-Host "  Timestamp : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "  Computer  : $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "================================================================" -ForegroundColor Cyan

# ── 1. Driver Files Check ─────────────────────────────────────────────────────
Print-Header "1. Driver Files in C:\IddSampleDriver"
$files = @('IddSampleDriver.dll', 'IddSampleDriver.inf', 'iddsampledriver.cer', 'iddsampledriver.cat', 'option.txt', 'Disconnect_RDP.bat')
$allFilesOk = $true
foreach ($f in $files) {
    $p = "C:\IddSampleDriver\$f"
    if (Test-Path $p) {
        $len = (Get-Item $p).Length
        Print-Result $f "EXISTS ($([math]::Round($len/1KB, 1)) KB)" "Green"
    } else {
        Print-Result $f "MISSING" "Red"
        $allFilesOk = $false
    }
}

if (Test-Path "C:\IddSampleDriver\option.txt") {
    $cfgLines = Get-Content "C:\IddSampleDriver\option.txt" -ErrorAction SilentlyContinue
    if ($cfgLines -and $cfgLines.Count -gt 0) {
        $count = $cfgLines[0].Trim()
        Print-Result "Configured Virtual Displays" "$count Monitor(s)" "Yellow"
    }
}

# ── 2. Certificate in Windows Certificate Store ───────────────────────────────
Print-Header "2. Windows Certificate Store Check"
try {
    $rootCerts = Get-ChildItem -Path Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | Where-Object { $_.Subject -match "IddSample" -or $_.Issuer -match "IddSample" }
    if ($rootCerts) {
        Print-Result "Trusted Root Store" "INSTALLED ($($rootCerts[0].Thumbprint.Substring(0,12))...)" "Green"
    } else {
        Print-Result "Trusted Root Store" "NOT FOUND" "Red"
    }

    $pubCerts = Get-ChildItem -Path Cert:\LocalMachine\TrustedPublisher -ErrorAction SilentlyContinue | Where-Object { $_.Subject -match "IddSample" -or $_.Issuer -match "IddSample" }
    if ($pubCerts) {
        Print-Result "Trusted Publisher Store" "INSTALLED ($($pubCerts[0].Thumbprint.Substring(0,12))...)" "Green"
    } else {
        Print-Result "Trusted Publisher Store" "NOT FOUND" "Red"
    }
} catch {
    Print-Result "Certificate Query Error" $_.Exception.Message "Red"
}

# ── 3. Device Manager / PnP Check ─────────────────────────────────────────────
Print-Header "3. Display Devices (Device Manager via PnPUtil)"
$pnp = & pnputil.exe /enum-devices /class Display 2>&1
$pnpStr = $pnp -join "`n"

$driverFound = $false
$driverRunning = $false

if ($pnpStr -match "IddSample") {
    $driverFound = $true
    Print-Result "IddSampleDriver Device" "FOUND IN DEVICE MANAGER" "Green"
    if ($pnpStr -match "Status:\s+Started") {
        $driverRunning = $true
        Print-Result "IddSampleDriver Status" "STARTED (Active & Ready)" "Green"
    } else {
        Print-Result "IddSampleDriver Status" "NOT STARTED / ERROR" "Red"
    }
} else {
    Print-Result "IddSampleDriver Device" "NOT FOUND (Driver not installed or device node missing)" "Red"
}

$pnpProblems = & pnputil.exe /enum-devices /class Display /problem 2>&1
$pnpProblemStr = $pnpProblems -join "`n"
if ($pnpProblemStr -match "Instance ID:") {
    Add-Log "`n[Display Devices with Problems]"
    Add-Log $pnpProblemStr
    Write-Host "  [WARNING] Devices with problems detected in Display class:" -ForegroundColor Red
    Write-Host "  $pnpProblemStr" -ForegroundColor Yellow
} else {
    Print-Result "Problem Devices in Display" "NONE (All display devices healthy)" "Green"
}

# ── 4. Active Video Controllers & Monitors ────────────────────────────────────
Print-Header "4. Active Video Controllers & Screen Resolution"
try {
    $controllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
    if ($controllers) {
        foreach ($vc in $controllers) {
            $res = if ($vc.CurrentHorizontalResolution) { "$($vc.CurrentHorizontalResolution)x$($vc.CurrentVerticalResolution) @ $($vc.CurrentRefreshRate)Hz" } else { "No active resolution" }
            Print-Result ($vc.Name) "Status: $($vc.Status) | Res: $res" "Yellow"
        }
    } else {
        Write-Host "  No Win32_VideoController found." -ForegroundColor Yellow
        Add-Log "  No Win32_VideoController found."
    }
} catch {
    Write-Host "  Error querying video controllers: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $screens = [System.Windows.Forms.Screen]::AllScreens
    Print-Result "Total Active Screens Detected" "$($screens.Count) Screen(s)" $(if ($screens.Count -gt 0) { "Green" } else { "Red" })
    for ($i = 0; $i -lt $screens.Count; $i++) {
        $s = $screens[$i]
        $primaryStr = if ($s.Primary) { "[Primary]" } else { "" }
        Print-Result "  Screen #$($i+1) $primaryStr" "$($s.Bounds.Width)x$($s.Bounds.Height) at ($($s.Bounds.X),$($s.Bounds.Y))" "Gray"
    }
} catch {}

# ── 5. Registry Settings Check ────────────────────────────────────────────────
Print-Header "5. Remote Desktop & WDDM Registry Settings"
$wddm = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fEnableWddmDriver' -ErrorAction SilentlyContinue).fEnableWddmDriver
if ($wddm -eq 1) { Print-Result "fEnableWddmDriver" "1 (Enabled - Recommended)" "Green" } else { Print-Result "fEnableWddmDriver" "$wddm (Not set to 1)" "Yellow" }

$suppress = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client' -Name 'RemoteDesktop_SuppressWhenMinimized' -ErrorAction SilentlyContinue).RemoteDesktop_SuppressWhenMinimized
if ($suppress -eq 2) { Print-Result "SuppressWhenMinimized" "2 (Enabled - Remote rendering kept alive)" "Green" } else { Print-Result "SuppressWhenMinimized" "$suppress (Not set to 2)" "Yellow" }

$envCfg = [System.Environment]::GetEnvironmentVariable("IDD_SAMPLE_DRIVER_CONFIG", "Machine")
if ($envCfg) { Print-Result "IDD_SAMPLE_DRIVER_CONFIG" "$envCfg" "Green" } else { Print-Result "IDD_SAMPLE_DRIVER_CONFIG" "NOT SET" "Red" }

# ── 6. Network & Power Management Check (Anti-Disconnect) ─────────────────────
Print-Header "6. Power Plan & Network Adapter Sleep Settings"
try {
    $plan = & powercfg.exe /getactivescheme 2>&1
    Print-Result "Active Power Scheme" "$($plan -join ' ')" "Yellow"
} catch {}

try {
    $netAdapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
    foreach ($na in $netAdapters) {
        Print-Result "Active Network Adapter" "$($na.Name) ($($na.InterfaceDescription))" "Green"
    }
} catch {}

try {
    $pingOk = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($pingOk) {
        Print-Result "Internet Connectivity (8.8.8.8)" "ONLINE (Ping OK)" "Green"
    } else {
        Print-Result "Internet Connectivity (8.8.8.8)" "OFFLINE or Ping blocked" "Yellow"
    }
} catch {}

# ── 7. TeamViewer Status (Critical for Remote Screen Capture) ─────────────────
Print-Header "7. TeamViewer Service & Process Status"
$tvSvc = Get-Service -Name 'TeamViewer' -ErrorAction SilentlyContinue
$tvSvcRunning = $false
if ($tvSvc) {
    $tvSvcRunning = ($tvSvc.Status -eq 'Running')
    $c = if ($tvSvcRunning) { 'Green' } else { 'Red' }
    Print-Result "TeamViewer Windows Service" "$($tvSvc.Status)" $c
    Print-Result "TeamViewer Startup Type" "$($tvSvc.StartType)" $(if ($tvSvc.StartType -eq 'Automatic') { 'Green' } else { 'Yellow' })
} else {
    Print-Result "TeamViewer Windows Service" "NOT INSTALLED AS SERVICE" "Red"
}

$tvProc = Get-Process -Name "TeamViewer*", "teamviewer*" -ErrorAction SilentlyContinue
$session0Found = $false
if ($tvProc) {
    foreach ($p in $tvProc) {
        if ($p.SessionId -eq 0) { $session0Found = $true }
        Print-Result "  Process $($p.ProcessName) (PID $($p.Id))" "Session ID: $($p.SessionId) (Session 0=Service, >0=User Session)" $(if ($p.SessionId -eq 0) { "Green" } else { "Yellow" })
    }
} else {
    Print-Result "Running TeamViewer Processes" "NONE RUNNING" "Red"
}

if (-not $session0Found) {
    Write-Host "`n  [CRITICAL WARNING] TeamViewer is NOT running in Session 0 (Windows System Service)!" -ForegroundColor Red
    Write-Host "  -> If TeamViewer is running only in the User Session, closing RDP will suspend the app" -ForegroundColor Yellow
    Write-Host "     and make TeamViewer appear offline / disconnected from Internet!" -ForegroundColor Yellow
    Write-Host "  -> FIX: In TeamViewer -> Options -> General -> Check 'Start TeamViewer with Windows'." -ForegroundColor Yellow
    Add-Log "  [CRITICAL WARNING] TeamViewer is not running in Session 0. It will suspend on RDP disconnect!"
}

# ── 8. Active Windows Sessions ────────────────────────────────────────────────
Print-Header "8. Active Windows Sessions"
$sessions = & query.exe session 2>&1
$sessionsStr = $sessions -join "`n"
Write-Host $sessionsStr -ForegroundColor Gray
Add-Log $sessionsStr

# ── 9. Recent Installation Log ────────────────────────────────────────────────
Print-Header "9. Setup.exe Installation Log (Last 20 lines)"
$installLogPath = "C:\IddSampleDriver\install_log.txt"
if (Test-Path $installLogPath) {
    $tail = Get-Content $installLogPath -Tail 20 -ErrorAction SilentlyContinue
    foreach ($line in $tail) {
        Write-Host "  $line" -ForegroundColor Gray
        Add-Log "  $line"
    }
} else {
    Write-Host "  install_log.txt not found yet." -ForegroundColor Yellow
    Add-Log "  install_log.txt not found yet."
}

# ── 10. Summary & Actionable Recommendations ──────────────────────────────────
Print-Header "10. Summary & Recommendations"

if (-not $driverFound) {
    Write-Host "  [ACTION REQUIRED] Virtual Display Driver is NOT registered in Device Manager!" -ForegroundColor Red
    Write-Host "  -> Run Setup.exe as Administrator to install the driver." -ForegroundColor Yellow
    Add-Log "  [ACTION REQUIRED] Virtual Display Driver is NOT registered in Device Manager!"
} elseif (-not $driverRunning) {
    Write-Host "  [ACTION REQUIRED] Virtual Display Driver is installed but NOT STARTED." -ForegroundColor Red
    Write-Host "  -> Run Setup.exe again as Administrator or check install_log.txt." -ForegroundColor Yellow
    Add-Log "  [ACTION REQUIRED] Virtual Display Driver is installed but NOT STARTED."
} else {
    Write-Host "  [OK] Virtual Display Driver is INSTALLED and ACTIVE!" -ForegroundColor Green
    Add-Log "  [OK] Virtual Display Driver is INSTALLED and ACTIVE!"
}

if (-not $tvSvcRunning -or -not $session0Found) {
    Write-Host "  [ACTION REQUIRED] TeamViewer MUST run as a Windows System Service (Session 0)." -ForegroundColor Red
    Write-Host "  -> Open TeamViewer -> Extras -> Options -> General -> Check 'Start TeamViewer with Windows'." -ForegroundColor Yellow
    Add-Log "  [ACTION REQUIRED] Enable 'Start TeamViewer with Windows' in TeamViewer options."
}

Write-Host "  [CRITICAL STEP TO DISCONNECT RDP]:" -ForegroundColor Cyan
Write-Host "  -> DO NOT click the [X] button on the Remote Desktop title bar!" -ForegroundColor Red
Write-Host "  -> Instead, double-click 'Disconnect_RDP.bat' on the Desktop (Run as Admin)." -ForegroundColor Green
Write-Host "     This transfers your active session to the Virtual Monitor (Console) so" -ForegroundColor White
Write-Host "     Windows does NOT lock, suspend desktop rendering, or disconnect network!" -ForegroundColor White
Add-Log "  [TIP] Run Disconnect_RDP.bat instead of clicking [X] on RDP."

# ── Save Log Files ────────────────────────────────────────────────────────────
$destLogs = @(
    (Join-Path $ScriptDir "server_diagnostic.txt"),
    "C:\IddSampleDriver\server_diagnostic.txt",
    (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)) "server_diagnostic.txt")
)

foreach ($dl in $destLogs) {
    try {
        $p = Split-Path -Parent $dl
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
        [IO.File]::WriteAllLines($dl, $logLines, [Text.Encoding]::UTF8)
    } catch {}
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  Diagnostic complete! Log saved to: C:\IddSampleDriver\server_diagnostic.txt" -ForegroundColor Green
Write-Host "================================================================`n" -ForegroundColor Cyan
