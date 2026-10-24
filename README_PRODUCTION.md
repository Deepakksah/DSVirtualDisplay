# Headless Server Deployment Guide (Virtual Display Driver)

Yeh package headless Windows Server (bina physical monitor ke) ke liye taiyar kiya gaya hai.

---

## 📁 Files Included

* `Release\Setup.exe` — **⭐ Single Standalone GUI Installer** (All-in-one: DLL, INF, CER embedded; No dependencies!)
* `install.bat` — **1-Click Script Installer** (GUI dialog khulega, monitor count select karo, auto install)
* `install.ps1` — Automation script (GUI, config, registry, certificates, device registration)
* `build_setup.ps1` — Builds the single self-contained `Setup.exe`
* `uninstall.bat` — **1-Click Uninstaller** (Driver, device aur registry completely remove karega)
* `uninstall.ps1` — Driver cleanup automation script
* `IddSampleDriver\` — Pre-compiled driver files (DLL, INF, CER, CAT)

---

## 🚀 Production Server Par Kaise Chalayein

### Option 1: Standalone `Setup.exe` (Sabse Aasan / Recommended)
Sirf `Release\Setup.exe` ko target server par copy karein:
1. `Setup.exe` par right-click karein → **"Run as administrator"**.
2. GUI khulega: 1 se 5 monitors choose karein → **"Install Now"** dabayein.
3. Done! Saare driver files, certificates, WDDM registry settings automatic install ho jaate hain.

---

### Option 2: Script-based Deployment
Agar folder ke through run karna ho:

2. **Pre-built Driver Files confirm karein:**
   Ensure karein ki yeh files `IddSampleDriver\` folder mein hain:
   * `IddSampleDriver.dll`
   * `IddSampleDriver.cer`
   * `IddSampleDriver.inf`

3. **Install Karein:**
   * `install.bat` par right-click karein aur **"Run as administrator"** select karein.
   * Ek **GUI dialog box** khulega jisme aap choose kar sakte hain:

     | Option | Monitors |
     |--------|----------|
     | 1 Virtual Monitor | ✅ Recommended / Default |
     | 2 Virtual Monitors | — |
     | 3 Virtual Monitors | — |
     | 4 Virtual Monitors | — |
     | 5 Virtual Monitors | — |

   * Apna option select karein → **"Install Now"** dabao.
   * Script automatically:
     - `option.txt` me aapki pasand ka monitor count set karega aur `C:\IddSampleDriver\option.txt` me copy karega.
     - RDP WDDM registry settings auto-apply karega.
     - Driver Certificate Windows Trusted Store mein register karega.
     - Virtual display device attach / refresh karega.

4. **Agar Monitors ki sankhya badalni ho:**
   * Kabhi bhi dobara `install.bat` chalayein → GUI mein nayi count select karein → Install Now.
   * Driver bina server restart ke update ho jayega!

5. **TeamViewer / AnyDesk Black Screen Fix (RDP band karne ke baad):**
   * Jab aap RDP window ko seedha `[X]` se close karte hain, Windows session ko lock kar deta hai.
   * Isliye RDP close karne ke liye **`Disconnect_RDP.bat`** par double click karein (ya Right-click → Run as admin).
   * Yeh session ko **Virtual Monitor** par live chhod dega, aur TeamViewer par screen kabhi black nahi hogi!

6. **Agar Remove Karna Ho:**
   * `uninstall.bat` par right-click karke **"Run as administrator"** select karein.

---

## ⚠️ Requirements

* Windows 10 / Windows 11 / Windows Server 2016 or later
* Administrator privileges required
* `.NET Framework 4.x` (pre-installed on all modern Windows — needed for GUI)
* Test signing mode enabled OR valid certificate (included: `IddSampleDriver.cer`)

