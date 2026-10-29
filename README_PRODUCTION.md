# Headless Server Deployment Guide (Virtual Display Driver)

Yeh package headless Windows Server (bina physical monitor ke) ke liye taiyar kiya gaya hai.
Remote access tools (TeamViewer, AnyDesk, UltraViewer) ke saath **bina kisi black screen ya freeze ke** kaam karta hai.

---

## 📁 Files Included

| File | Kaam |
|------|------|
| `Release\Setup.exe` | ⭐ **Single Standalone GUI Installer** — Sabse aasan, koi dependency nahi |
| `install.bat` | 1-Click Script Installer (GUI dialog) |
| `install.ps1` | Full automation script |
| `build_setup.ps1` | Setup.exe rebuild karne ka script |
| `uninstall.bat` | 1-Click Uninstaller |
| `Auto_Console_Handoff.ps1` | Auto-Unlock script (installer deploy karta hai) |
| `Disconnect_RDP.bat` | Manual safe RDP disconnect helper |
| `Check_Status.bat/.ps1` | System diagnostic tool |
| `IddSampleDriver\` | Pre-compiled driver files (DLL, INF, CER, CAT) |

---

## 🚀 Installation — Sirf 3 Steps!

### Step 1: Setup.exe Copy Karo
`Release\Setup.exe` ko apne server par copy karo (koi aur file ki zaroorat nahi).

### Step 2: Run as Administrator
`Setup.exe` par right-click karein → **"Run as administrator"**

### Step 3: Monitor Select Karo → Install Now
GUI mein 1 se 5 Virtual Monitors choose karo → **"Install Now"** dabao.

**Bas! Sab kuch automatic ho jayega:**

```
✅ Virtual Display Driver install
✅ option.txt configure (1080p, 2K, 4K modes)
✅ Registry tweaks (WDDM, RDP settings)
✅ Sleep/timeout disable (never sleep)
✅ Driver certificate trusted
✅ Auto-Unlock Task register (NEW!)
   → RDP [X] dabane par screen freeze nahi hogi
   → UltraViewer/TeamViewer/AnyDesk hamesha live rahega
```

---

## 🔓 Auto-Unlock Feature (NEW — v2.0)

### ❌ Pehle kya problem thi:
- Jab RDP window ka `[X]` dabate the → Windows session **lock/freeze** ho jaata tha
- UltraViewer / TeamViewer bolta tha: *"Cannot capture screen at the moment"*
- Screen **black** ho jaati thi

### ✅ Ab kya hota hai (Automatic):
```
RDP [X] dabaya
      ↓ (< 1 second, kuch nahi karna)
Windows Auto-Unlock Task triggers
      ↓
tscon.exe → Session Virtual Monitor Console par move
      ↓
Screen LIVE rahti hai ✅
UltraViewer/TeamViewer/AnyDesk = No black screen ✅
```

**Yeh sab Setup.exe install karte waqt automatically set ho jaata hai.**  
Aapko kuch alag se karne ki zaroorat nahi hai!

---

## 💡 Headless Server Use Case (Real Example)

**Delhi Office → Bangalore Server (bina physical monitor)**

| Situation | Result |
|-----------|--------|
| Seedha TeamViewer se connect | ✅ Full HD 1080p live screen |
| Seedha AnyDesk se connect | ✅ Perfect, no setup needed |
| Seedha UltraViewer se connect | ✅ Live screen, no freeze |
| RDP `[X]` dabaane ke baad | ✅ Auto-Unlock — screen freeze nahi hogi |
| Server reboot ke baad | ✅ Virtual Monitor auto-start |

**Ab Delhi se Bangalore server ka remote lene ke liye RDP ki zaroorat nahi!**  
Seedha TeamViewer/AnyDesk ID → Connect → Done ✅

---

## 🔄 Monitor Count Badlana

Kabhi bhi `Setup.exe` ya `install.bat` dobara chalayein → nayi count select karein → Install Now.  
**Server restart ki zaroorat nahi!**

---

## 🗑️ Uninstall Karna

`uninstall.bat` par right-click → **"Run as administrator"**  
Driver, registry, device node, aur Auto-Unlock Task sab remove ho jaayenge.

---

## 🔍 Diagnostic Tool

Agar kuch check karna ho:
- `Check_Status.bat` → Double-click (Run as admin)
- Report `C:\IddSampleDriver\server_diagnostic.txt` mein save hogi
- Auto-Unlock log: `C:\IddSampleDriver\autounlock.log`

---

## ⚠️ Requirements

- Windows 10 / Windows 11 / Windows Server 2016 ya baad ka
- Administrator privileges zaroori hai
- `.NET Framework 4.x` (modern Windows mein pre-installed — GUI ke liye)
- Koi physical monitor zaroori nahi — fully headless kaam karta hai!
