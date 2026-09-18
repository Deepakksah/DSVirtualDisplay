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

# 2. Interactive Monitor Count Selection
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "  Virtual Monitors Configuration" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Yellow
Write-Host "  Aap kitne Virtual Monitors banana chahte hain?" -ForegroundColor White
Write-Host "  [1] - 1 Virtual Monitor (Recommended / Default)" -ForegroundColor Cyan
Write-Host "  [2] - 2 Virtual Monitors" -ForegroundColor Cyan
Write-Host "  [3] - 3 Virtual Monitors" -ForegroundColor Cyan
Write-Host "  [4] - 4 Virtual Monitors" -ForegroundColor Cyan
Write-Host "  [5] - 5 Virtual Monitors" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor Gray
$inputCount = Read-Host "Number enter karein (1-5) [Enter dabayein for 1]"

$numDisplays = 1
if ($inputCount -match '^[1-5]$') {
    $numDisplays = [int]$inputCount
}
Write-Host "`n  -> Target: $numDisplays Virtual Monitor(s) configure kiye ja rahe hain..." -ForegroundColor Green

# 3. Setup Configuration Directory and option.txt
$ConfigDir = "C:\IddSampleDriver"
$ConfigFile = Join-Path $ConfigDir "option.txt"
$SourceOption = Join-Path $ScriptDir "option.txt"

Write-Host "`n[1/5] Configuring Display Settings..." -ForegroundColor Green
if (-not (Test-Path $ConfigDir)) {
    Write-Host "  Creating directory: $ConfigDir" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

if (Test-Path $SourceOption) {
    $lines = Get-Content $SourceOption
    if ($lines.Count -gt 0) {
        $lines[0] = "$numDisplays"
        $lines | Set-Content $SourceOption -Encoding ascii
        $lines | Set-Content $ConfigFile -Encoding ascii
    } else {
        Copy-Item -Path $SourceOption -Destination $ConfigFile -Force
    }
    Write-Host "  Successfully set $numDisplays display(s) in $ConfigFile" -ForegroundColor Gray
} else {
    @"
$numDisplays
#lines beginning with "#" are ignored
1920, 1080, 60
2560, 1440, 60
3840, 2160, 60
"@ | Out-File -FilePath $ConfigFile -Encoding ascii
    Write-Host "  Created $ConfigFile with $numDisplays display(s)." -ForegroundColor Gray
}

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
Write-Host "  Applied WDDM & Hardware Graphics policy in Terminal Services." -ForegroundColor Gray

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
