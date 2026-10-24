# ==============================================================================
# IddSampleDriver - Automated 1-Click Installer for Headless Production Server
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Virtual Display Driver - Automated 1-Click Installer    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Administrator Check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This installer must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click install.bat and select 'Run as administrator'." -ForegroundColor Yellow
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 2. GUI Monitor Count Selection (Windows Forms - Built-in, No extra library needed)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Virtual Display Driver - Setup"
$form.Size = New-Object System.Drawing.Size(420, 340)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 40)

# Title Label
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Virtual Monitor Setup"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 255)
$lblTitle.Location = New-Object System.Drawing.Point(20, 18)
$lblTitle.Size = New-Object System.Drawing.Size(370, 30)
$form.Controls.Add($lblTitle)

# Subtitle Label
$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Aap kitne Virtual Monitors banana chahte hain?"
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblSub.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$lblSub.Location = New-Object System.Drawing.Point(20, 55)
$lblSub.Size = New-Object System.Drawing.Size(370, 22)
$form.Controls.Add($lblSub)

# Separator line (panel)
$sep = New-Object System.Windows.Forms.Panel
$sep.Location = New-Object System.Drawing.Point(20, 82)
$sep.Size = New-Object System.Drawing.Size(370, 2)
$sep.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 80)
$form.Controls.Add($sep)

# Radio buttons for monitor count
$radioButtons = @()
$labels = @(
    "1 Virtual Monitor  (Recommended / Default)",
    "2 Virtual Monitors",
    "3 Virtual Monitors",
    "4 Virtual Monitors",
    "5 Virtual Monitors"
)

for ($i = 0; $i -lt 5; $i++) {
    $rb = New-Object System.Windows.Forms.RadioButton
    $rb.Text = $labels[$i]
    $rb.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $rb.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
    $rb.BackColor = [System.Drawing.Color]::Transparent
    $rb.Location = New-Object System.Drawing.Point(30, (95 + $i * 34))
    $rb.Size = New-Object System.Drawing.Size(350, 28)
    $rb.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($i -eq 0) { $rb.Checked = $true }
    $form.Controls.Add($rb)
    $radioButtons += $rb
}

# OK Button
$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Text = "Install Now"
$btnOK.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnOK.ForeColor = [System.Drawing.Color]::White
$btnOK.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnOK.FlatStyle = "Flat"
$btnOK.FlatAppearance.BorderSize = 0
$btnOK.Location = New-Object System.Drawing.Point(20, 268)
$btnOK.Size = New-Object System.Drawing.Size(175, 38)
$btnOK.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnOK)
$form.AcceptButton = $btnOK

# Cancel Button
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnCancel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 75)
$btnCancel.FlatStyle = "Flat"
$btnCancel.FlatAppearance.BorderSize = 0
$btnCancel.Location = New-Object System.Drawing.Point(215, 268)
$btnCancel.Size = New-Object System.Drawing.Size(175, 38)
$btnCancel.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($btnCancel)
$form.CancelButton = $btnCancel

# Show the form
$result = $form.ShowDialog()

if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "`n[INFO] Installation cancelled by user." -ForegroundColor Yellow
    exit 0
}

# Get selected monitor count
$numDisplays = 1
for ($i = 0; $i -lt 5; $i++) {
    if ($radioButtons[$i].Checked) {
        $numDisplays = $i + 1
        break
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "  Virtual Monitors Configuration" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "`n  -> Target: $numDisplays Virtual Monitor(s) configure kiye ja rahe hain..." -ForegroundColor Green

# 3. Setup Configuration Directory — Generate option.txt from embedded resolutions
$ConfigDir = "C:\IddSampleDriver"
$ConfigFile = Join-Path $ConfigDir "option.txt"

# All supported resolutions are embedded here — no external option.txt needed
$embeddedResolutions = @(
    "1920, 1080, 60",
    "2560, 1440, 60",
    "3840, 2160, 60",
    "1600,  900, 60",
    "1440,  900, 60",
    "1366,  768, 60",
    "1280, 1024, 60",
    "1280,  800, 60",
    "1280,  720, 60",
    "1024,  768, 60",
    " 800,  600, 60",
    " 640,  480, 60"
)

Write-Host "`n[1/5] Configuring Display Settings..." -ForegroundColor Green
if (-not (Test-Path $ConfigDir)) {
    Write-Host "  Creating directory: $ConfigDir" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

# Generate option.txt directly from embedded data
$configLines = @("$numDisplays") + $embeddedResolutions
$configLines | Set-Content $ConfigFile -Encoding ascii
Write-Host "  Generated $ConfigFile with $numDisplays display(s) and $($embeddedResolutions.Count) resolution modes." -ForegroundColor Gray

# Set Environment Variable for config file path
[Environment]::SetEnvironmentVariable("IDD_SAMPLE_DRIVER_CONFIG", $ConfigFile, "Machine")
Write-Host "  Environment variable IDD_SAMPLE_DRIVER_CONFIG configured." -ForegroundColor Gray

# 4. Apply Registry Configurations for Remote Desktop & WDDM Graphics
Write-Host "`n[2/5] Applying Remote Desktop & WDDM Registry Settings..." -ForegroundColor Green

# A. Terminal Services Policies
$tsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
if (-not (Test-Path $tsPolicyPath)) {
    New-Item -Path $tsPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $tsPolicyPath -Name "fEnableWddmDriver" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $tsPolicyPath -Name "bEnUserSettings" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $tsPolicyPath -Name "fEnableHardwareMode" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $tsPolicyPath -Name "MaxDisconnectionTime" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $tsPolicyPath -Name "MaxIdleTime" -Value 0 -Type DWord -Force
Write-Host "  Applied WDDM, Hardware Graphics & Anti-Timeout policy in Terminal Services." -ForegroundColor Gray

# B. Terminal Server WinStations
$winStationsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations"
if (Test-Path $winStationsPath) {
    Set-ItemProperty -Path $winStationsPath -Name "EnableWddmDriver" -Value 1 -Type DWord -Force
    Write-Host "  Enabled WDDM driver support in WinStations." -ForegroundColor Gray
}

# C. Remote Desktop Graphics Pipe
$rdpPipePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
if (Test-Path $rdpPipePath) {
    Set-ItemProperty -Path $rdpPipePath -Name "fEnableWddmDriver" -Value 1 -Type DWord -Force
}

# D. Anti-Blackscreen Keep-Alive when Minimized/Disconnected
$clientRegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Terminal Server Client",
    "HKCU:\Software\Microsoft\Terminal Server Client",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client"
)
foreach ($crp in $clientRegPaths) {
    if (-not (Test-Path $crp)) { New-Item -Path $crp -Force | Out-Null }
    Set-ItemProperty -Path $crp -Name "RemoteDesktop_SuppressWhenMinimized" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
}
Write-Host "  Applied RemoteDesktop_SuppressWhenMinimized = 2 (prevents black screen on minimize)." -ForegroundColor Gray

# E. Deploy Disconnect_RDP.bat to Desktop
$sourceDisconnectBat = Join-Path $ScriptDir "Disconnect_RDP.bat"
if (Test-Path $sourceDisconnectBat) {
    Copy-Item -Path $sourceDisconnectBat -Destination (Join-Path $ConfigDir "Disconnect_RDP.bat") -Force
    $desktopPaths = @(
        [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonDesktopDirectory),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
    )
    foreach ($dp in $desktopPaths) {
        if ($dp -and (Test-Path $dp)) {
            Copy-Item -Path $sourceDisconnectBat -Destination (Join-Path $dp "Disconnect_RDP.bat") -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  Deployed Disconnect_RDP.bat to Desktop for 1-click safe RDP disconnect." -ForegroundColor Gray
}

# 5. Locate Driver Files & Install Certificate
Write-Host "`n[3/5] Locating Driver Files & Certificates..." -ForegroundColor Green

$InfFile = $null
$PossibleInfPaths = @(
    (Join-Path $ScriptDir "IddSampleDriver.inf"),
    (Join-Path $ScriptDir "IddSampleDriver\IddSampleDriver.inf"),
    (Join-Path $ScriptDir "driver_bin\IddSampleDriver.inf")
)

foreach ($path in $PossibleInfPaths) {
    if (Test-Path $path) {
        $InfFile = (Get-Item $path).FullName
        break
    }
}

if (-not $InfFile) {
    Write-Host "[ERROR] Could not find IddSampleDriver.inf!" -ForegroundColor Red
    exit 1
}
Write-Host "  Found INF file: $InfFile" -ForegroundColor Gray

$DriverDir = Split-Path -Parent $InfFile
$CerFiles = Get-ChildItem -Path $ScriptDir, $DriverDir -Filter "*.cer" -Recurse -ErrorAction SilentlyContinue | Select-Object -Unique -ExpandProperty FullName

if ($CerFiles) {
    foreach ($cer in $CerFiles) {
        Write-Host "  Adding Certificate to Trusted Stores: $cer" -ForegroundColor Gray
        & certutil.exe -addstore -f "Root" $cer | Out-Null
        & certutil.exe -addstore -f "TrustedPublisher" $cer | Out-Null
    }
    Write-Host "  Certificate successfully registered in Windows Trusted Store." -ForegroundColor Gray
} else {
    Write-Host "  No .cer file found (proceeding if system accepts test driver)." -ForegroundColor Yellow
}

# 6. Add / Update Device
Write-Host "`n[4/5] Installing / Updating Virtual Display Device..." -ForegroundColor Green

$devcon = Get-Command "devcon.exe" -ErrorAction SilentlyContinue
$nefcon = Get-Command "nefcon.exe" -ErrorAction SilentlyContinue

if (-not $devcon) {
    $localDevcon = Get-ChildItem -Path $ScriptDir, $DriverDir -Filter "devcon.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($localDevcon) { $devcon = $localDevcon.FullName }
}

if (-not $nefcon) {
    $localNefcon = Get-ChildItem -Path $ScriptDir, $DriverDir -Filter "nefcon.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($localNefcon) { $nefcon = $localNefcon.FullName }
}

# Check if device is already present
$existingDevice = & pnputil.exe /enum-devices /class Display | Select-String -Pattern "IddSample"
$installed = $false

if ($existingDevice) {
    Write-Host "  Virtual display device is already installed. Reloading with $numDisplays monitor(s)..." -ForegroundColor Cyan
    & pnputil.exe /restart-device /deviceid "Root\IddSampleDriver" 2>$null | Out-Null
    $installed = $true
} else {
    # Method A: nefcon
    if ($nefcon) {
        Write-Host "  Using nefcon to install device node..." -ForegroundColor Cyan
        & $nefcon --install-driver --inf-path $InfFile
        $installed = $true
    }
    # Method B: devcon
    elseif ($devcon) {
        Write-Host "  Using devcon to install device node..." -ForegroundColor Cyan
        & $devcon install $InfFile "Root\IddSampleDriver"
        $installed = $true
    }
    # Method C: Windows Native SetupAPI + PnPUtil
    else {
        Write-Host "  Adding driver package to Windows Driver Store via PnPUtil..." -ForegroundColor Cyan
        $pnpOutput = & pnputil.exe /add-driver $InfFile /install 2>&1
        Write-Host "  $($pnpOutput -join "`n  ")" -ForegroundColor Gray

        $CSharpSource = @"
using System;
using System.Runtime.InteropServices;

public class DeviceInstaller {
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid ClassGuid, IntPtr hwndParent);

    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool SetupDiCreateDeviceInfo(IntPtr DeviceInfoSet, string DeviceName, ref Guid ClassGuid, string DeviceDescription, IntPtr hwndParent, uint CreationFlags, ref SP_DEVINFO_DATA DeviceInfoData);

    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool SetupDiSetDeviceRegistryProperty(IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, uint Property, byte[] PropertyBuffer, uint PropertyBufferSize);

    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool SetupDiCallClassInstaller(uint InstallFunction, IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData);

    [DllImport("setupapi.dll", SetLastError = true)]
    public static extern bool SetupDiDestroyDeviceInfoList(IntPtr DeviceInfoSet);

    [DllImport("newdev.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool UpdateDriverForPlugAndPlayDevices(IntPtr hwndParent, string HardwareId, string FullInfPath, uint InstallFlags, out bool RebootRequired);

    [StructLayout(LayoutKind.Sequential)]
    public struct SP_DEVINFO_DATA {
        public uint cbSize;
        public Guid ClassGuid;
        public uint DevInst;
        public IntPtr Reserved;
    }

    public const uint DICD_GENERATE_ID = 0x00000001;
    public const uint SPDRP_HARDWAREID = 0x00000001;
    public const uint DIF_REGISTERDEVICE = 0x00000019;
    public const uint INSTALLFLAG_FORCE = 0x00000001;

    public static bool InstallRootDevice(string hardwareId, string infPath, out string error) {
        error = "";
        Guid displayClass = new Guid("{4d36e968-e325-11ce-bfc1-08002be10318}");
        IntPtr devInfo = SetupDiCreateDeviceInfoList(ref displayClass, IntPtr.Zero);
        if (devInfo == (IntPtr)(-1)) {
            error = "SetupDiCreateDeviceInfoList failed: " + Marshal.GetLastWin32Error();
            return false;
        }

        try {
            SP_DEVINFO_DATA devData = new SP_DEVINFO_DATA();
            devData.cbSize = (uint)Marshal.SizeOf(typeof(SP_DEVINFO_DATA));

            if (!SetupDiCreateDeviceInfo(devInfo, "IddSampleDriver", ref displayClass, "IddSampleDriver Device", IntPtr.Zero, DICD_GENERATE_ID, ref devData)) {
                error = "SetupDiCreateDeviceInfo failed: " + Marshal.GetLastWin32Error();
                return false;
            }

            byte[] hwIdBytes = System.Text.Encoding.Unicode.GetBytes(hardwareId + "\0\0");
            if (!SetupDiSetDeviceRegistryProperty(devInfo, ref devData, SPDRP_HARDWAREID, hwIdBytes, (uint)hwIdBytes.Length)) {
                error = "SetupDiSetDeviceRegistryProperty failed: " + Marshal.GetLastWin32Error();
                return false;
            }

            if (!SetupDiCallClassInstaller(DIF_REGISTERDEVICE, devInfo, ref devData)) {
                error = "SetupDiCallClassInstaller(DIF_REGISTERDEVICE) failed: " + Marshal.GetLastWin32Error();
                return false;
            }

            bool reboot = false;
            if (!UpdateDriverForPlugAndPlayDevices(IntPtr.Zero, hardwareId, infPath, INSTALLFLAG_FORCE, out reboot)) {
                error = "UpdateDriverForPlugAndPlayDevices failed: " + Marshal.GetLastWin32Error();
                return false;
            }

            return true;
        }
        catch (Exception ex) {
            error = ex.Message;
            return false;
        }
        finally {
            SetupDiDestroyDeviceInfoList(devInfo);
        }
    }
}
"@
        try {
            Add-Type -TypeDefinition $CSharpSource -ErrorAction Stop
            Write-Host "  Creating Root device node (Root\IddSampleDriver)..." -ForegroundColor Cyan
            $err = ""
            $res = [DeviceInstaller]::InstallRootDevice("Root\IddSampleDriver", $InfFile, [ref]$err)
            if ($res) {
                Write-Host "  Root Device node successfully created and driver attached!" -ForegroundColor Green
                $installed = $true
            } else {
                Write-Host "  Direct node registration notice: $err" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  Native installer notice: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# 7. Verify and Refresh
Write-Host "`n[5/5] Rescanning Devices..." -ForegroundColor Green
& pnputil.exe /scan-devices | Out-Null
Start-Sleep -Seconds 2

$devices = & pnputil.exe /enum-devices /class Display
$match = $devices | Select-String -Pattern "IddSample"

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($match -or $installed) {
    Write-Host "  [SUCCESS] $numDisplays Virtual Monitor(s) Configured Successfully!" -ForegroundColor Green
    Write-Host "  * Active Monitors: $numDisplays" -ForegroundColor White
    Write-Host "  * Configuration: $ConfigFile" -ForegroundColor Gray
    Write-Host "  * Registry settings applied (RDP WDDM graphics enabled)" -ForegroundColor Gray
} else {
    Write-Host "  Setup completed. If monitors do not appear immediately, please restart server." -ForegroundColor Yellow
}
Write-Host "==========================================================" -ForegroundColor Cyan
