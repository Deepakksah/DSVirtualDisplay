# Headless Server Deployment Guide (Virtual Display Driver)

Yeh package headless Windows Server (bina physical monitor ke) ke liye taiyar kiya gaya hai.

---

## 📁 Files Included

* [install.bat](file:///install.bat) - **1-Click Interactive Installer** (Kitne monitors chahiye poochhega, registry apply karega, driver install karega)
* [install.ps1](file:///install.ps1) - Background automation script jo monitors count, config, registry, certificates aur device register karta hai
* [uninstall.bat](file:///uninstall.bat) - **1-Click Uninstaller** (Driver, device aur registry ko completely remove karega)
* [uninstall.ps1](file:///uninstall.ps1) - Driver cleanup automation script
* [option.txt](file:///option.txt) - Virtual monitor configuration (monitors ki sankhya aur resolutions)

---

## 🚀 Production Server Par Kaise Chalayein

1. **Folder Copy Karein:**
   Is poore folder ko apne production server par copy kar lijiye.

2. **Pre-built Driver Files:**
   Ensure karein ki yeh files is folder me hon:
   * `IddSampleDriver.dll`
   * `IddSampleDriver.cer`
   * `IddSampleDriver.inf`

3. **Install Karein:**
   * [install.bat](file:///install.bat) par right-click karein aur **"Run as administrator"** select karein.
   * Console screen aapse poochhegi:
     ```text
     Aap kitne Virtual Monitors banana chahte hain?
     [1] - 1 Virtual Monitor (Default)
     [2] - 2 Virtual Monitors
     [3] - 3 Virtual Monitors
     [4] - 4 Virtual Monitors
     [5] - 5 Virtual Monitors
     Number enter karein (1-5):
     ```
   * Bas number daal kar **Enter** dabaiye!
   * Script automatically:
     - `option.txt` me aapki pasand ka monitor count set karega aur `C:\IddSampleDriver\option.txt` me save karega.
     - RDP WDDM registry settings auto-apply karega.
     - Driver Certificate trust karega.
     - Virtual display device attach / refresh karega.

4. **Agar Monitors ki sankhya badalni ho:**
   * Kabhi bhi dobara `install.bat` chalakar naya number enter karein, driver bina server restart kiye update ho jayega!

5. **Agar Remove Karna Ho:**
   * [uninstall.bat](file:///uninstall.bat) par right-click karke **"Run as administrator"** select karein.
