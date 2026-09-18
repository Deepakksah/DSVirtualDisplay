# DSVirtualDisplay - Automated Virtual Display Driver for Windows

**DSVirtualDisplay** is an automated solution for creating and managing **Virtual Displays (Monitors)** on Windows and Windows Server without requiring any physical monitor, dummy HDMI plug, or display hardware.

Built on Microsoft's **IddCx (Indirect Display Driver Class Extension)** user-mode framework, it allows seamless headless server management, high-resolution remote desktop access (RDP, AnyDesk, TeamViewer, Parsec, Moonlight/Sunshine), multi-monitor testing, and screen streaming.

---

## 🌟 Key Features

* **⚡ 1-Click Interactive Installation (`install.bat`):**
  - Easily choose the number of virtual monitors (**1 to 5 displays**) interactively via the terminal.
* **🛠️ Automated Registry Configuration:**
  - Automatically configures Windows Remote Desktop (RDP) **WDDM Graphics Driver** policies (`fEnableWddmDriver = 1`, `EnableWddmDriver = 1`) to eliminate the *"The display settings can't be changed from a remote session"* restriction.
* **📁 Auto-Configuration Management:**
  - Creates `C:\IddSampleDriver\` and deploys `option.txt` with your selected display count and resolutions.
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
├── IddSampleDriver/             # Driver C++ source code and INF configuration
│   ├── Driver.cpp
│   ├── Driver.h
│   └── IddSampleDriver.inf
├── install.bat                  # 1-Click Administrator Launcher for Installer
├── install.ps1                  # Interactive setup engine (config, registry, device creation)
├── uninstall.bat                # 1-Click Administrator Launcher for Uninstaller
├── uninstall.ps1                # Clean removal engine (device removal & driver cleanup)
├── option.txt                   # Monitor resolution & display count configuration
├── IddSampleDriver.sln          # Visual Studio solution file
└── README.md                    # Project documentation & usage guide
```

---

## 🚀 How to Run & Install (Step-by-Step)

### Step 1: Ensure Required Driver Files are Present
To install the driver on your target machine/server, ensure the following files are inside this directory:
1. `IddSampleDriver.inf` (included in repo)
2. `IddSampleDriver.dll` (driver binary)
3. `IddSampleDriver.cer` (driver certificate)

> **Note:** If you do not have pre-built `.dll` and `.cer` files, download `IddSampleDriver.zip` from [IddSampleDriver Releases](https://github.com/ge9/IddSampleDriver/releases/latest) and place them directly into this directory.

---

### Step 2: Run the 1-Click Installer
1. Right-click on **`install.bat`** and select **"Run as administrator"**.
2. A console window will appear asking:
   ```text
   ==========================================================
     Virtual Monitors Configuration
   ==========================================================
     Aap kitne Virtual Monitors banana chahte hain?
     [1] - 1 Virtual Monitor (Recommended / Default)
     [2] - 2 Virtual Monitors
     [3] - 3 Virtual Monitors
     [4] - 4 Virtual Monitors
     [5] - 5 Virtual Monitors
   ----------------------------------------------------------
   Number enter karein (1-5) [Enter dabayein for 1]:
   ```
3. Type the number of virtual monitors you want (`1`, `2`, `3`, `4`, or `5`) and press **Enter**. *(Pressing Enter directly chooses 1 monitor).*

---

### Step 3: What the Installer Automates
The script automatically:
* Creates `C:\IddSampleDriver\` and updates `option.txt` with your chosen monitor count.
* Enables Remote Desktop WDDM display driver in Windows Registry.
* Registers the driver certificate into Windows Trusted Root Store.
* Registers the device node (`Root\IddSampleDriver`) and attaches the virtual display.

---

### Step 4: Verify & Use Your Virtual Displays
1. Press `Win + R`, type `desk.cpl`, and hit **Enter** to open **Display Settings**.
2. You will see your new virtual monitors (**Display 1**, **Display 2**, etc.).
3. Choose your desired resolution:
   - `1920 x 1080` (Full HD 60Hz)
   - `2560 x 1440` (2K 60Hz)
   - `3840 x 2160` (4K 60Hz)
4. Now you can connect via **Remote Desktop (RDP)**, **AnyDesk**, **TeamViewer**, or **Parsec** and enjoy full resolution on a headless server without physical screens!

---

## 🔄 How to Change Monitor Count Later
If you already have 1 virtual monitor running and want to switch to 2 or 3 monitors:
1. Simply run **`install.bat`** as Administrator again.
2. Enter the new number (e.g., `2`).
3. The script will automatically update `option.txt` and reload the virtual display driver immediately without rebooting!

---

## 🗑️ How to Completely Uninstall
To remove the virtual display driver and all associated device nodes:
1. Right-click on **`uninstall.bat`** and select **"Run as administrator"**.
2. The uninstaller will:
   - Remove the `Root\IddSampleDriver` device node.
   - Delete the driver package from the Windows Driver Store.
   - Clean up applied registry keys and environment variables.

---

## 📜 License
Licensed under MIT / CC0 / Public Domain.
Based on Microsoft's Indirect Display Driver Sample and community contributions by `ge9` and `roshkins`.
