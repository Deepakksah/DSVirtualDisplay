# ==============================================================================
# IddSampleDriver - Automated 1-Click Uninstaller
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "  Virtual Display Driver - 1-Click Uninstaller            " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow

# 1. Administrator Check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This uninstaller must be run as Administrator!" -ForegroundColor Red
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 2. Remove Device Instance
Write-Host "`n[1/4] Removing Virtual Display Device..." -ForegroundColor Cyan

$devcon = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
$nefcon = Get-Command "nefcon.exe" -ErrorAction SilentlyContinue

if (-not $devcon) {
    $localDevcon = Get-ChildItem -Path $ScriptDir -Filter "devcon.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($localDevcon) { $devcon = $localDevcon.FullName }
}

if (-not $nefcon) {
    $localNefcon = Get-ChildItem -Path $ScriptDir -Filter "nefcon.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($localNefcon) { $nefcon = $localNefcon.FullName }
}

if ($nefcon) {
    & $nefcon --remove-device-node --hardware-id "Root\IddSampleDriver"
}
elseif ($devcon) {
    & $devcon remove "Root\IddSampleDriver"
}
else {
    $enumOutput = & pnputil.exe /enum-devices /class Display /deviceids
    $instanceId = $null
    $lines = $enumOutput -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "Root\\IddSampleDriver") {
            for ($j = $i; $j -ge [Math]::Max(0, $i - 5); $j--) {
                if ($lines[$j] -match "Instance ID:\s*(.+)$") {
                    $instanceId = $Matches[1].Trim()
                    break
                }
            }
            if ($instanceId) { break }
        }
    }

    if ($instanceId) {
        Write-Host "  Found device instance: $instanceId" -ForegroundColor Gray
        & pnputil.exe /remove-device "$instanceId"
    } else {
        Write-Host "  Attempting to remove device matching Root\IddSampleDriver..." -ForegroundColor Gray
        & pnputil.exe /remove-device /deviceid "Root\IddSampleDriver" 2>$null
    }
}

# 3. Delete Driver Package from Driver Store
Write-Host "`n[2/4] Removing Driver Package from Driver Store..." -ForegroundColor Cyan
$drivers = & pnputil.exe /enum-drivers
$oemInfs = @()
$currentOem = ""

foreach ($line in ($drivers -split "`r?`n")) {
    if ($line -match "Published Name:\s*(oem\d+\.inf)") {
        $currentOem = $Matches[1]
    }
    if ($line -match "IddSampleDriver" -and $currentOem) {
        $oemInfs += $currentOem
        $currentOem = ""
    }
}

foreach ($oem in ($oemInfs | Select-Object -Unique)) {
    Write-Host "  Deleting driver package $oem..." -ForegroundColor Gray
    & pnputil.exe /delete-driver $oem /uninstall /force
}

# 4. Clean Registry & Environment Variable
Write-Host "`n[3/4] Cleaning Registry Settings..." -ForegroundColor Cyan
[Environment]::SetEnvironmentVariable("IDD_SAMPLE_DRIVER_CONFIG", $null, "Machine")
$tsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
if (Test-Path $tsPolicyPath) {
    Remove-ItemProperty -Path $tsPolicyPath -Name "fEnableWddmDriver" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $tsPolicyPath -Name "bEnUserSettings" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $tsPolicyPath -Name "fEnableHardwareMode" -ErrorAction SilentlyContinue
}

# 5. Rescan Devices
Write-Host "`n[4/4] Rescanning Devices..." -ForegroundColor Cyan
& pnputil.exe /scan-devices | Out-Null

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  [SUCCESS] Virtual Display Driver successfully removed! " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
