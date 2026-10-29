# DSVirtualDisplay - Automated Virtual Display Driver for Windows

**DSVirtualDisplay** is an automated solution for creating and managing **Virtual Displays (Monitors)** on Windows and Windows Server without requiring any physical monitor, dummy HDMI plug, or display hardware.

Built on Microsoft's **IddCx (Indirect Display Driver Class Extension)** user-mode framework, it allows seamless headless server management, high-resolution remote desktop access (RDP, AnyDesk, TeamViewer, UltraViewer, Parsec, Moonlight/Sunshine), multi-monitor testing, and screen streaming.

---

## 🌟 Key Features

* **📦 Standalone 1-Click GUI Installer (`Release/Setup.exe`):**
  - Completely self-contained single executable (~655 KB) with embedded driver binaries (DLL, INF, CER, CAT).
  - Modern dark-mode GUI to select virtual monitor count (1 to 5 displays) with live installation progress.
  - Zero external dependencies — no PowerShell scripts or separate DLL files needed on the target machine!
* **🔓 Auto-Unlock on RDP Disconnect (NEW!):**
  - Automatically registers a Windows Scheduled Task that triggers on every RDP disconnect event.
  - Uses `tscon.exe` to silently transfer the desktop session to the Virtual Display Console — no lock, no black screen, no freeze.
  - UltraViewer, TeamViewer, AnyDesk stay **live and connected 24/7** even after pressing RDP `[X]`.
* **⚡ Script-Based Interactive GUI (`install.bat`):**
  - Built-in Windows Forms dialog with customizable monitor selection.
* **🛠️ Automated Registry Configuration:**
  - Automatically configures Windows Remote Desktop (RDP) **WDDM Graphics Driver** policies (`fEnableWddmDriver = 1`, `EnableWddmDriver = 1`) to eliminate the *"The display settings can't be changed from a remote session"* restriction.
  - Sets `RemoteDesktop_SuppressWhenMinimized = 2` to prevent screen freeze when RDP window is minimized.
  - Disables all sleep/standby timeouts (`powercfg` — monitor, sleep, disk, hibernate = 0).
* **📁 Auto-Configuration Management:**
  - Creates `C:\IddSampleDriver\` and generates display configuration with 16+ high-resolution modes (from 640x480 up to 4K/8K).
* **🔐 Auto-Trust Driver Certificate:**
  - Silently imports the driver certificate into Windows **Trusted Root Certification Authorities** and **TrustedPublisher** stores.
* **🛡️ Crash-Safe User-Mode Driver (UMDF):**
  - Runs in User Mode (not kernel mode), ensuring your system will never suffer a Blue Screen of Death (BSOD).
* **🧹 1-Click Clean Uninstallation (`uninstall.bat`):**
  - Instantly uninstalls the driver, removes device nodes, and cleans up registry entries in a single click.

---

## 📁 Repository Structure

```text
DSVirtualDisplay/
├── Release/
│   └── Setup.exe                     # ⭐ Single standalone GUI installer (All-in-one)
├── build_setup.ps1                   # Builder script to compile Setup.exe (uses built-in csc.exe)
├── IddSampleDriver/                  # Driver C++ source code, binaries and INF
│   ├── Driver.cpp
│   ├── Driver.h
│   ├── IddSampleDriver.dll
│   ├── iddsampledriver.cer
│   └── IddSampleDriver.inf
├── Auto_Console_Handoff.ps1          # Auto-Unlock script (deployed by installer to C:\IddSampleDriver\)
├── install.bat                       # 1-Click Launcher for Script Installer
├── install.ps1                       # Modern GUI setup engine
├── uninstall.bat                     # 1-Click Launcher for Uninstaller
├── uninstall.ps1                     # Clean removal engine
├── Disconnect_RDP.bat                # Manual safe RDP disconnect helper
├── Check_Status.bat / .ps1           # System diagnostic tool
├── IddSampleDriver.sln               # Visual Studio solution file
└── README.md                         # Project documentation & usage guide
```

---

## 🚀 How to Install (Step-by-Step)

### ✅ Option 1: Standalone `Setup.exe` — Recommended (Zero Dependencies)

This is the **easiest and recommended method**. Just copy a single file to the target server.

1. Copy `Release\Setup.exe` to the server.
2. Right-click → **"Run as administrator"**.
3. GUI opens — select **1 to 5 Virtual Monitors** → click **"Install Now"**.
4. Done! Everything below happens **fully automatically**:

---

### ⚙️ What the Installer Does Automatically

| # | Action | Details |
|---|--------|---------|
| 1 | **Extract Driver Files** | `IddSampleDriver.dll`, `.inf`, `.cer`, `.cat` → `C:\IddSampleDriver\` |
| 2 | **Configure option.txt** | Sets your selected monitor count + 16+ resolution modes |
| 3 | **Registry Tweaks** | WDDM enabled, RDP suppress minimized, KeepAlive on |
| 4 | **Sleep Disabled** | Monitor/Sleep/Hibernate timeout = 0 (powercfg) |
| 5 | **Certificate Trusted** | Driver cert added to Root + TrustedPublisher stores |
| 6 | **Driver Installed** | `Root\IddSampleDriver` device node created via SetupAPI |
| 7 | **Auto-Unlock Task** | `Auto_Console_Handoff.ps1` deployed + Windows Scheduled Task registered |

---

### ✅ Option 2: Script-Based Installer (`install.bat`)

1. Right-click on **`install.bat`** → **"Run as administrator"**.
2. A modern dark-mode GUI dialog will appear — select monitor count → click **"Install Now"**.
3. All 7 steps above are performed automatically including the Auto-Unlock Task.

---

## 🔓 Auto-Unlock Feature — How It Works

### ❓ Problem (Before)
When a user connects via **RDP** and then **closes the RDP window `[X]`**, Windows:
- Locks and freezes the desktop session
- Stops GPU screen rendering
- Causes UltraViewer/TeamViewer/AnyDesk to show: *"Cannot capture screen at the moment"* or black screen

### ✅ Solution (Auto-Unlock — Built into Installer)

The installer automatically deploys two components:

**1. `C:\IddSampleDriver\Auto_Console_Handoff.ps1`**
```powershell
# When triggered, finds the disconnected RDP session and transfers it to Virtual Console
for ($i=1; $i -le 5; $i++) {
    # Find disconnected session ID using: query session
    if ($sid) {
        tscon.exe $sid /dest:console   # Transfer to Virtual Monitor — NO LOCK!
        break
    }
    Start-Sleep -Seconds 1
}
```

**2. Windows Scheduled Task: `AutoUnlockConsoleOnRDPDisconnect`**
```
Trigger  : Windows Event ID 24 (Address != LOCAL)
           (TerminalServices-LocalSessionManager — "Remote Session Disconnected")
Action   : Run Auto_Console_Handoff.ps1 silently (SYSTEM account)
Delay    : < 1 second after remote disconnect
```

**Result Flow:**
```
User presses RDP [X]
       ↓
Windows fires Event ID 24 (RDP Disconnected)
       ↓  (< 1 second, automatic)
AutoUnlockConsoleOnRDPDisconnect task starts
       ↓
tscon.exe transfers session → Virtual Display Console
       ↓
Desktop stays LIVE and UNLOCKED ✅
UltraViewer / TeamViewer / AnyDesk = No black screen ✅
```

**Log file:** `C:\IddSampleDriver\autounlock.log` — every trigger is recorded.

---

## 🎯 Use Case: Headless Remote Server (No Physical Monitor)

**Scenario:** Delhi office → Bangalore server (no physical monitor attached)

| Method | Before (Problem) | After (Solution) |
|--------|-----------------|-----------------|
| Direct TeamViewer | ❌ Black Screen (no display rendering) | ✅ Live 1080p Full HD |
| RDP then TeamViewer | ❌ Screen freezes when RDP `[X]` pressed | ✅ Auto-transfers to Virtual Display |
| Direct AnyDesk | ❌ "Cannot capture screen" | ✅ Works perfectly |
| After reboot | ❌ Manual steps needed | ✅ Auto-starts on boot |

---

## 🔄 How to Change Monitor Count Later

1. Run **`Setup.exe`** (or `install.bat`) again as Administrator.
2. Select new monitor count → **"Install Now"**.
3. Driver reloads immediately — **no reboot required!**

---

## 🗑️ How to Completely Uninstall

1. Right-click on **`uninstall.bat`** → **"Run as administrator"**.
2. The uninstaller will:
   - Remove the `Root\IddSampleDriver` device node.
   - Delete the driver package from the Windows Driver Store.
   - Clean up registry keys and environment variables.
   - Remove `AutoUnlockConsoleOnRDPDisconnect` scheduled task.

---

## 🏗️ How to Rebuild Setup.exe

If you want to rebuild `Setup.exe` from source (e.g., after modifying the driver):

```powershell
# Run as Administrator — uses built-in .NET csc.exe (no extra tools needed!)
powershell -ExecutionPolicy Bypass -File build_setup.ps1
```

Output: `Release\Setup.exe` (self-contained, ~655 KB)

---

## 📋 Requirements

- Windows 10 / Windows 11 / Windows Server 2016 or later
- Administrator privileges required
- `.NET Framework 4.x` (pre-installed on all modern Windows — needed for GUI)
- Test signing mode enabled OR valid certificate (included: `IddSampleDriver.cer`)
- No physical monitor required — works fully headless!

---

## 📜 License

Licensed under MIT / CC0 / Public Domain.  
Based on Microsoft's Indirect Display Driver Sample and community contributions by `ge9` and `roshkins`.
