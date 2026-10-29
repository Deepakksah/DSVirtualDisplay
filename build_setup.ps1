# ==============================================================================
# build_setup.ps1 - Builds a single self-contained Setup.exe with embedded diagnostics
# Embeds: IddSampleDriver.dll, .inf, .cer, .cat, Check_Status.bat, Check_Status.ps1
# Uses csc.exe (built-in .NET C# compiler) — No external tools needed
# ==============================================================================

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$DriverDir  = Join-Path $ScriptDir "IddSampleDriver"
$ReleaseDir = Join-Path $ScriptDir "Release"
$OutputExe  = Join-Path $ReleaseDir "Setup.exe"
$TempCs     = Join-Path $env:TEMP "DSVirtualDisplay_Setup.cs"

Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  DSVirtualDisplay - Single EXE Builder with Full Diagnostics" -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan

# Ensure Release dir
if (-not (Test-Path $ReleaseDir)) { New-Item -ItemType Directory -Path $ReleaseDir | Out-Null }

# ── Step 1: Encode files as Base64 ────────────────────────────────────────────
Write-Host "`n[1/3] Embedding driver & diagnostic files..." -ForegroundColor Green

$filePaths = @{
    DLL    = Join-Path $DriverDir "IddSampleDriver.dll"
    INF    = Join-Path $DriverDir "IddSampleDriver.inf"
    CER    = Join-Path $DriverDir "iddsampledriver.cer"
    CAT    = Join-Path $DriverDir "iddsampledriver.cat"
    CHKBAT = Join-Path $ScriptDir "Check_Status.bat"
    CHKPS1 = Join-Path $ScriptDir "Check_Status.ps1"
}

foreach ($kv in $filePaths.GetEnumerator()) {
    if (-not (Test-Path $kv.Value)) {
        Write-Host "[ERROR] Missing: $($kv.Value)" -ForegroundColor Red
        exit 1
    }
}

$dllB64    = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.DLL))
$infB64    = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.INF))
$cerB64    = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.CER))
$catB64    = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.CAT))
$chkBatB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.CHKBAT))
$chkPs1B64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.CHKPS1))

Write-Host "  DLL    : $([math]::Round($dllB64.Length*3/4/1KB,1)) KB"
Write-Host "  INF    : $([math]::Round($infB64.Length*3/4/1KB,1)) KB"
Write-Host "  CER    : $([math]::Round($cerB64.Length*3/4/1KB,1)) KB"
Write-Host "  CAT    : $([math]::Round($catB64.Length*3/4/1KB,1)) KB"
Write-Host "  CHKBAT : $([math]::Round($chkBatB64.Length*3/4/1KB,1)) KB"
Write-Host "  CHKPS1 : $([math]::Round($chkPs1B64.Length*3/4/1KB,1)) KB"

# ── Step 2: Write C# source file ──────────────────────────────────────────────
Write-Host "`n[2/3] Generating C# source..." -ForegroundColor Green

$template = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using System.Security.Principal;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

static class Program {
    const string EmbeddedDll    = "__DLL_B64__";
    const string EmbeddedInf    = "__INF_B64__";
    const string EmbeddedCer    = "__CER_B64__";
    const string EmbeddedCat    = "__CAT_B64__";
    const string EmbeddedChkBat = "__CHKBAT_B64__";
    const string EmbeddedChkPs1 = "__CHKPS1_B64__";

    static readonly string LogFile = @"C:\IddSampleDriver\install_log.txt";

    [STAThread]
    static void Main() {
        if (!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) {
            try {
                Process.Start(new ProcessStartInfo(System.Reflection.Assembly.GetExecutingAssembly().Location) {
                    Verb = "runas",
                    UseShellExecute = true
                });
            } catch {}
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        int count = ShowMonitorDialog();
        if (count < 1) return;

        ShowInstallForm(count);
    }

    static int ShowMonitorDialog() {
        Color bg   = Color.FromArgb(28, 28, 38);
        Color blue = Color.FromArgb(0, 120, 215);
        Color txt  = Color.FromArgb(220, 220, 230);
        Color sub  = Color.FromArgb(160, 160, 175);

        Form f = new Form {
            Text = "Virtual Display Driver - Setup",
            Size = new Size(450, 380),
            StartPosition = FormStartPosition.CenterScreen,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MaximizeBox = false,
            MinimizeBox = false,
            BackColor = bg
        };

        f.Controls.Add(new Label {
            Text = "Virtual Monitor Setup",
            Font = new Font("Segoe UI", 15, FontStyle.Bold),
            ForeColor = Color.FromArgb(90, 190, 255),
            Location = new Point(20, 18),
            Size = new Size(400, 32),
            BackColor = Color.Transparent
        });

        f.Controls.Add(new Label {
            Text = "Select number of Virtual Monitors to create for Headless Server:",
            Font = new Font("Segoe UI", 9),
            ForeColor = sub,
            Location = new Point(22, 54),
            Size = new Size(400, 22),
            BackColor = Color.Transparent
        });

        f.Controls.Add(new Panel {
            Location = new Point(20, 80),
            Size = new Size(395, 1),
            BackColor = Color.FromArgb(55, 55, 72)
        });

        string[] opts = {
            "  1 Virtual Monitor   (Recommended / Headless Server)",
            "  2 Virtual Monitors",
            "  3 Virtual Monitors",
            "  4 Virtual Monitors",
            "  5 Virtual Monitors"
        };

        RadioButton[] rbs = new RadioButton[5];
        for (int i = 0; i < 5; i++) {
            rbs[i] = new RadioButton {
                Text = opts[i],
                Font = new Font("Segoe UI", 10),
                ForeColor = txt,
                BackColor = Color.Transparent,
                Location = new Point(26, 92 + i * 36),
                Size = new Size(385, 30),
                Checked = (i == 0),
                Cursor = Cursors.Hand
            };
            f.Controls.Add(rbs[i]);
        }

        Button ok = new Button {
            Text = "  Install Now",
            Font = new Font("Segoe UI", 10, FontStyle.Bold),
            ForeColor = Color.White,
            BackColor = blue,
            FlatStyle = FlatStyle.Flat,
            Location = new Point(20, 285),
            Size = new Size(190, 42),
            Cursor = Cursors.Hand,
            DialogResult = DialogResult.OK
        };
        ok.FlatAppearance.BorderSize = 0;
        f.Controls.Add(ok);
        f.AcceptButton = ok;

        Button cn = new Button {
            Text = "  Cancel",
            Font = new Font("Segoe UI", 10),
            ForeColor = sub,
            BackColor = Color.FromArgb(58, 58, 72),
            FlatStyle = FlatStyle.Flat,
            Location = new Point(225, 285),
            Size = new Size(190, 42),
            Cursor = Cursors.Hand,
            DialogResult = DialogResult.Cancel
        };
        cn.FlatAppearance.BorderSize = 0;
        f.Controls.Add(cn);
        f.CancelButton = cn;

        if (f.ShowDialog() != DialogResult.OK) return -1;
        for (int i = 0; i < 5; i++) {
            if (rbs[i].Checked) return i + 1;
        }
        return 1;
    }

    static void ShowInstallForm(int count) {
        Color bg  = Color.FromArgb(28, 28, 38);
        Color txt = Color.FromArgb(220, 220, 230);
        Color grn = Color.FromArgb(80, 200, 100);
        Color red = Color.FromArgb(255, 90, 90);
        Color sub = Color.FromArgb(160, 160, 175);
        Color blue = Color.FromArgb(0, 120, 215);

        Form pf = new Form {
            Text = "Virtual Display Driver - Installation & Diagnostics",
            Size = new Size(540, 450),
            StartPosition = FormStartPosition.CenterScreen,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MaximizeBox = false,
            MinimizeBox = false,
            BackColor = bg
        };

        Label lbl = new Label {
            Text = "Installing Virtual Display Driver...",
            Font = new Font("Segoe UI", 11, FontStyle.Bold),
            ForeColor = Color.FromArgb(90, 190, 255),
            Location = new Point(20, 16),
            Size = new Size(485, 26),
            BackColor = Color.Transparent
        };
        pf.Controls.Add(lbl);

        ProgressBar pb = new ProgressBar {
            Location = new Point(20, 46),
            Size = new Size(485, 16),
            Minimum = 0,
            Maximum = 100,
            Value = 0,
            Style = ProgressBarStyle.Continuous
        };
        pf.Controls.Add(pb);

        ListBox log = new ListBox {
            Location = new Point(20, 72),
            Size = new Size(485, 280),
            BackColor = Color.FromArgb(18, 18, 26),
            ForeColor = txt,
            Font = new Font("Consolas", 8.5f),
            BorderStyle = BorderStyle.FixedSingle,
            HorizontalScrollbar = true
        };
        pf.Controls.Add(log);

        Button btnLog = new Button {
            Text = "Open Log",
            Font = new Font("Segoe UI", 9),
            ForeColor = Color.White,
            BackColor = Color.FromArgb(50, 70, 95),
            FlatStyle = FlatStyle.Flat,
            Location = new Point(20, 362),
            Size = new Size(110, 34),
            Cursor = Cursors.Hand,
            Enabled = false
        };
        btnLog.FlatAppearance.BorderSize = 0;
        btnLog.Click += (s, e) => {
            try { Process.Start("notepad.exe", LogFile); } catch {}
        };
        pf.Controls.Add(btnLog);

        Button btnCheck = new Button {
            Text = "Run Diagnostics",
            Font = new Font("Segoe UI", 9),
            ForeColor = Color.White,
            BackColor = Color.FromArgb(60, 60, 80),
            FlatStyle = FlatStyle.Flat,
            Location = new Point(140, 362),
            Size = new Size(130, 34),
            Cursor = Cursors.Hand,
            Enabled = false
        };
        btnCheck.FlatAppearance.BorderSize = 0;
        btnCheck.Click += (s, e) => {
            string chk = @"C:\IddSampleDriver\Check_Status.bat";
            if (File.Exists(chk)) {
                try { Process.Start(new ProcessStartInfo(chk) { UseShellExecute = true }); } catch {}
            }
        };
        pf.Controls.Add(btnCheck);

        Button btnClose = new Button {
            Text = "Close",
            Font = new Font("Segoe UI", 9, FontStyle.Bold),
            ForeColor = sub,
            BackColor = Color.FromArgb(50, 50, 65),
            FlatStyle = FlatStyle.Flat,
            Location = new Point(405, 362),
            Size = new Size(100, 34),
            Cursor = Cursors.Hand,
            Enabled = false
        };
        btnClose.FlatAppearance.BorderSize = 0;
        btnClose.Click += (s, e) => pf.Close();
        pf.Controls.Add(btnClose);

        pf.Show();
        Application.DoEvents();

        Action<string, int> logMsg = (msg, pct) => {
            string line = string.Format("[{0}] {1}", DateTime.Now.ToString("HH:mm:ss"), msg);
            log.Items.Add(line);
            log.TopIndex = log.Items.Count - 1;
            if (pct >= 0 && pct <= 100) pb.Value = pct;
            try {
                string dir = Path.GetDirectoryName(LogFile);
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                File.AppendAllText(LogFile, line + "\r\n");
            } catch {}
            Application.DoEvents();
        };

        bool ok = false;
        try {
            try {
                string dir = Path.GetDirectoryName(LogFile);
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                File.WriteAllText(LogFile, string.Format("=== DSVirtualDisplay Setup Log ({0}) ===\r\n\r\n", DateTime.Now));
            } catch {}

            logMsg("Extracting driver files to C:\\IddSampleDriver...", 10);
            string cfgDir = @"C:\IddSampleDriver";
            if (!Directory.Exists(cfgDir)) Directory.CreateDirectory(cfgDir);

            string dll = Path.Combine(cfgDir, "IddSampleDriver.dll");
            string inf = Path.Combine(cfgDir, "IddSampleDriver.inf");
            string cer = Path.Combine(cfgDir, "iddsampledriver.cer");
            string cat = Path.Combine(cfgDir, "iddsampledriver.cat");
            string bat = Path.Combine(cfgDir, "Disconnect_RDP.bat");
            string chkBat = Path.Combine(cfgDir, "Check_Status.bat");
            string chkPs1 = Path.Combine(cfgDir, "Check_Status.ps1");

            File.WriteAllBytes(dll, Convert.FromBase64String(EmbeddedDll));
            File.WriteAllBytes(inf, Convert.FromBase64String(EmbeddedInf));
            File.WriteAllBytes(cer, Convert.FromBase64String(EmbeddedCer));
            File.WriteAllBytes(cat, Convert.FromBase64String(EmbeddedCat));
            File.WriteAllBytes(chkBat, Convert.FromBase64String(EmbeddedChkBat));
            File.WriteAllBytes(chkPs1, Convert.FromBase64String(EmbeddedChkPs1));

            logMsg("  Extracted driver, cert, and diagnostic utilities.", 20);

            logMsg("Configuring display options...", 28);
            string cfgFile = Path.Combine(cfgDir, "option.txt");
            var resList = new List<string> {
                count.ToString(),
                "1920, 1080, 60", "2560, 1440, 60", "3840, 2160, 60",
                "1600,  900, 60", "1440,  900, 60", "1366,  768, 60",
                "1280, 1024, 60", "1280,  800, 60", "1280,  720, 60",
                "1024,  768, 60", " 800,  600, 60", " 640,  480, 60"
            };
            File.WriteAllLines(cfgFile, resList.ToArray());
            Environment.SetEnvironmentVariable("IDD_SAMPLE_DRIVER_CONFIG", cfgFile, EnvironmentVariableTarget.Machine);
            logMsg(string.Format("  Configured {0} virtual display(s) in option.txt.", count), 35);

            logMsg("Creating Disconnect_RDP.bat helper script...", 40);
            string rdpBatContent = "@echo off\r\nnet session >nul 2>&1\r\nif %errorlevel% neq 0 ( powershell -NoProfile -Command \"Start-Process -FilePath ''%~f0'' -Verb RunAs\" & exit /b )\r\necho Transferring RDP session to Virtual Display (Console)...\r\npowershell -NoProfile -Command \"$s=(Get-Process -Id $PID).SessionId; & tscon.exe $s /dest:console\"\r\n";
            File.WriteAllText(bat, rdpBatContent);

            string[] desktops = {
                Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory),
                Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory)
            };
            foreach (string d in desktops) {
                if (!string.IsNullOrEmpty(d) && Directory.Exists(d)) {
                    try { File.WriteAllText(Path.Combine(d, "Disconnect_RDP.bat"), rdpBatContent); } catch {}
                    try { File.Copy(chkBat, Path.Combine(d, "Check_Status.bat"), true); } catch {}
                    try { File.Copy(chkPs1, Path.Combine(d, "Check_Status.ps1"), true); } catch {}
                }
            }
            logMsg("  Placed Disconnect_RDP.bat & Check_Status.bat on Desktop.", 46);

            logMsg("Configuring WDDM and Remote Desktop registry settings...", 52);
            ApplyReg(logMsg);

            logMsg("Installing security certificate into Trusted Stores...", 60);
            InstallCertificate(cer, logMsg);

            logMsg("Registering driver package in DriverStore...", 70);
            string pnpAdd = Cmd("pnputil.exe", string.Format("/add-driver \"{0}\" /install", inf));
            if (!string.IsNullOrEmpty(pnpAdd)) {
                string[] pnpLines = pnpAdd.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (string l in pnpLines) {
                    if (l.IndexOf("Driver package added", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        l.IndexOf("published", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        l.IndexOf("successfully", StringComparison.OrdinalIgnoreCase) >= 0) {
                        logMsg("  PnPUtil: " + l.Trim(), -1);
                    }
                }
            }

            logMsg("Creating Root device node and binding driver...", 78);
            bool rootOk = InstallRootDevice(inf, logMsg);

            logMsg("Rescanning hardware devices (pnputil /scan-devices)...", 85);
            Cmd("pnputil.exe", "/scan-devices");

            logMsg("Verifying Virtual Display status in Device Manager...", 90);
            string pnpEnum = Cmd("pnputil.exe", "/enum-devices /class Display");
            bool driverActive = false;
            if (!string.IsNullOrEmpty(pnpEnum) && pnpEnum.IndexOf("IddSample", StringComparison.OrdinalIgnoreCase) >= 0) {
                if (pnpEnum.IndexOf("Started", StringComparison.OrdinalIgnoreCase) >= 0) {
                    driverActive = true;
                    logMsg("  [VERIFIED] IddSampleDriver is active and Started!", 96);
                } else {
                    logMsg("  [WARNING] IddSampleDriver found in Device Manager, but Status is not 'Started'.", 96);
                }
            } else {
                logMsg("  [WARNING] IddSampleDriver device was not detected in Display class.", 96);
            }

            logMsg("Setting up Auto-Unlock on RDP Disconnect...", 97);
            RegisterAutoUnlockTask(cfgDir, logMsg);

            if (driverActive || rootOk) {
                ok = true;
                logMsg(string.Format("SUCCESS! {0} Virtual Monitor(s) installed and ready.", count), 100);
                logMsg("  Auto-Unlock: ACTIVE - RDP [X] se screen ab freeze nahi hogi!", -1);
            } else {
                logMsg("INSTALLATION WARNING: Driver could not be confirmed as active.", 100);
                logMsg("Click 'Run Diagnostics' or 'Open Log' for detailed diagnostic info.", -1);
            }
        } catch (Exception ex) {
            logMsg("[CRITICAL ERROR] " + ex.Message, pb.Value);
        }

        lbl.Text = ok ? string.Format("+ {0} Virtual Monitor(s) ready!", count) : "- Installation completed with warnings";
        lbl.ForeColor = ok ? grn : red;
        btnLog.Enabled = true;
        btnCheck.Enabled = true;
        btnClose.Enabled = true;
        btnClose.BackColor = blue;
        btnClose.ForeColor = Color.White;
        pf.AcceptButton = btnClose;

        Application.Run(pf);
    }

    static void InstallCertificate(string cerPath, Action<string, int> logMsg) {
        try {
            byte[] raw = File.ReadAllBytes(cerPath);
            X509Certificate2 cert = new X509Certificate2(raw);

            using (X509Store store = new X509Store(StoreName.Root, StoreLocation.LocalMachine)) {
                store.Open(OpenFlags.ReadWrite);
                store.Add(cert);
                store.Close();
            }
            using (X509Store store = new X509Store(StoreName.TrustedPublisher, StoreLocation.LocalMachine)) {
                store.Open(OpenFlags.ReadWrite);
                store.Add(cert);
                store.Close();
            }
            logMsg("  Certificate added to LocalMachine Root & TrustedPublisher (.NET API).", -1);
        } catch (Exception ex) {
            logMsg("  .NET Cert store notice: " + ex.Message, -1);
        }

        string r1 = Cmd("certutil.exe", string.Format("-addstore -f Root \"{0}\"", cerPath));
        string r2 = Cmd("certutil.exe", string.Format("-addstore -f TrustedPublisher \"{0}\"", cerPath));
        if (r1 != null && r1.IndexOf("success", StringComparison.OrdinalIgnoreCase) >= 0) logMsg("  certutil Root store: OK.", -1);
        if (r2 != null && r2.IndexOf("success", StringComparison.OrdinalIgnoreCase) >= 0) logMsg("  certutil TrustedPublisher: OK.", -1);
    }

    static void ApplyReg(Action<string, int> logMsg) {
        string[] polKeys = {
            @"SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services",
            @"SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations",
            @"SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
        };
        foreach (string k in polKeys) {
            try {
                RegistryKey rk = Registry.LocalMachine.OpenSubKey(k, true) ?? Registry.LocalMachine.CreateSubKey(k);
                if (rk != null) {
                    rk.SetValue("fEnableWddmDriver", 1, RegistryValueKind.DWord);
                    rk.SetValue("EnableWddmDriver", 1, RegistryValueKind.DWord);
                    rk.SetValue("bEnUserSettings", 1, RegistryValueKind.DWord);
                    rk.SetValue("fEnableHardwareMode", 1, RegistryValueKind.DWord);
                    rk.SetValue("MaxDisconnectionTime", 0, RegistryValueKind.DWord);
                    rk.SetValue("MaxIdleTime", 0, RegistryValueKind.DWord);
                    rk.Close();
                }
            } catch {}
        }

        string[] clientKeys = {
            @"SOFTWARE\Microsoft\Terminal Server Client",
            @"SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client"
        };
        foreach (string k in clientKeys) {
            try {
                RegistryKey rk = Registry.LocalMachine.OpenSubKey(k, true) ?? Registry.LocalMachine.CreateSubKey(k);
                if (rk != null) {
                    rk.SetValue("RemoteDesktop_SuppressWhenMinimized", 2, RegistryValueKind.DWord);
                    rk.Close();
                }
            } catch {}
            try {
                RegistryKey rk = Registry.CurrentUser.OpenSubKey(k, true) ?? Registry.CurrentUser.CreateSubKey(k);
                if (rk != null) {
                    rk.SetValue("RemoteDesktop_SuppressWhenMinimized", 2, RegistryValueKind.DWord);
                    rk.Close();
                }
            } catch {}
        }

        try {
            RegistryKey rk = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Terminal Server", true);
            if (rk != null) {
                rk.SetValue("KeepAliveEnable", 1, RegistryValueKind.DWord);
                rk.SetValue("KeepAliveInterval", 1, RegistryValueKind.DWord);
                rk.Close();
            }
        } catch {}

        try {
            Cmd("powercfg.exe", "/change standby-timeout-ac 0");
            Cmd("powercfg.exe", "/change hibernate-timeout-ac 0");
            Cmd("powercfg.exe", "/change monitor-timeout-ac 0");
            Cmd("powercfg.exe", "/change disk-timeout-ac 0");
            logMsg("  Power Plan configured: Standby/Sleep disabled on AC power.", -1);
        } catch {}

        try {
            Cmd("powershell.exe", "-NoProfile -Command \"Get-NetAdapter | ForEach-Object { Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue }\"");
            logMsg("  Network adapter power-saving sleep disabled.", -1);
        } catch {}

        try {
            Cmd("sc.exe", "config TeamViewer start= auto");
            Cmd("net.exe", "start TeamViewer");
            Cmd("sc.exe", "config AnyDesk start= auto");
            Cmd("net.exe", "start AnyDesk");
            Cmd("sc.exe", "config UltraViewService start= auto");
            Cmd("net.exe", "start UltraViewService");
        } catch {}
        logMsg("  WDDM, Network KeepAlive, Remote Access services configured.", -1);
    }

    static void RegisterAutoUnlockTask(string cfgDir, Action<string, int> logMsg) {
        try {
            // 1. Deploy Auto_Console_Handoff.ps1
            string scriptPath = Path.Combine(cfgDir, "Auto_Console_Handoff.ps1");
            string script =
                "# Auto_Console_Handoff.ps1\r\n" +
                "# Transfers disconnected RDP session to Virtual Console automatically\r\n" +
                "# Prevents UltraViewer/TeamViewer/AnyDesk screen freeze when RDP [X] pressed\r\n" +
                "$log = 'C:\\IddSampleDriver\\autounlock.log'\r\n" +
                "function wl($m) { Add-Content $log \"[$(Get-Date -f 'HH:mm:ss')] $m\" -EA 0 }\r\n" +
                "wl 'Auto-Unlock triggered.'\r\n" +
                "Start-Sleep -Seconds 1\r\n" +
                "$sid = $null\r\n" +
                "for ($i=1; $i -le 3; $i++) {\r\n" +
                "    foreach ($ln in (& query session 2>&1)) {\r\n" +
                "        if ($ln -match '\\s+(\\d+)\\s+Disc\\b') { $n=[int]$Matches[1]; if($n -gt 0){$sid=$n;break} }\r\n" +
                "    }\r\n" +
                "    if ($sid) { break }\r\n" +
                "    Start-Sleep -Seconds 1\r\n" +
                "}\r\n" +
                "if ($sid) {\r\n" +
                "    wl \"Transferring disconnected session $sid to console...\";\r\n" +
                "    $out = & \"$env:windir\\System32\\tscon.exe\" $sid /dest:console 2>&1;\r\n" +
                "    wl \"Done. ($out)\";\r\n" +
                "} else {\r\n" +
                "    wl 'No disconnected session found. No action taken.';\r\n" +
                "}\r\n";
            File.WriteAllText(scriptPath, script, System.Text.Encoding.ASCII);
            logMsg("  Auto-Unlock script deployed: " + scriptPath, -1);

            // 2. Register Scheduled Task
            // Trigger: EventID=24 (RDP Session Disconnected) AND UserData/*[Address != 'LOCAL']
            // This ensures task fires ONLY on real remote RDP disconnect — NOT on reconnects or local console events
            string taskXml =
                "<?xml version=\"1.0\" encoding=\"UTF-16\"?>\r\n" +
                "<Task version=\"1.2\" xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">\r\n" +
                "  <RegistrationInfo><Description>Auto-Unlock Virtual Console on RDP Disconnect</Description></RegistrationInfo>\r\n" +
                "  <Triggers><EventTrigger><Enabled>true</Enabled>\r\n" +
                "    <Subscription>&lt;QueryList&gt;&lt;Query Id=\"0\" Path=\"Microsoft-Windows-TerminalServices-LocalSessionManager/Operational\"&gt;&lt;Select Path=\"Microsoft-Windows-TerminalServices-LocalSessionManager/Operational\"&gt;*[System[Provider[@Name='Microsoft-Windows-TerminalServices-LocalSessionManager'] and (EventID=24)] and UserData/*[Address != 'LOCAL']]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>\r\n" +
                "  </EventTrigger></Triggers>\r\n" +
                "  <Principals><Principal id=\"A\"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>\r\n" +
                "  <Settings>\r\n" +
                "    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>\r\n" +
                "    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>\r\n" +
                "    <AllowHardTerminate>true</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable>\r\n" +
                "    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>\r\n" +
                "    <IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>\r\n" +
                "    <AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><Hidden>true</Hidden>\r\n" +
                "    <RunOnlyIfIdle>false</RunOnlyIfIdle><WakeToRun>false</WakeToRun>\r\n" +
                "    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit><Priority>4</Priority>\r\n" +
                "  </Settings>\r\n" +
                "  <Actions Context=\"A\"><Exec>\r\n" +
                "    <Command>powershell.exe</Command>\r\n" +
                "    <Arguments>-WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + scriptPath + "\"</Arguments>\r\n" +
                "  </Exec></Actions>\r\n" +
                "</Task>";

            string xmlTmp = Path.Combine(Path.GetTempPath(), "AutoUnlockTask.xml");
            File.WriteAllText(xmlTmp, taskXml, System.Text.Encoding.Unicode);
            string r = Cmd("schtasks.exe", string.Format("/create /tn \"AutoUnlockConsoleOnRDPDisconnect\" /xml \"{0}\" /f", xmlTmp));
            try { File.Delete(xmlTmp); } catch {}

            if (!string.IsNullOrEmpty(r) && r.IndexOf("SUCCESS", StringComparison.OrdinalIgnoreCase) >= 0) {
                logMsg("  [OK] AutoUnlock Task registered! RDP [X] = Screen stays LIVE.", -1);
            } else {
                logMsg("  AutoUnlock Task note: " + (r ?? "").Trim(), -1);
            }
        } catch (Exception ex) {
            logMsg("  AutoUnlock notice: " + ex.Message, -1);
        }
    }

    static string Cmd(string exe, string args) {
        try {
            var p = new Process {
                StartInfo = new ProcessStartInfo(exe, args) {
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                }
            };
            p.Start();
            string o = p.StandardOutput.ReadToEnd();
            p.WaitForExit(15000);
            return o;
        } catch (Exception ex) {
            return "CMD_ERR: " + ex.Message;
        }
    }

    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid g, IntPtr h);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern bool SetupDiCreateDeviceInfo(IntPtr s, string n, ref Guid g, string d, IntPtr h, uint f, ref SPDD dd);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern bool SetupDiSetDeviceRegistryProperty(IntPtr s, ref SPDD d, uint p, byte[] b, uint sz);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern bool SetupDiCallClassInstaller(uint f, IntPtr s, ref SPDD d);
    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr s);
    [DllImport("newdev.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern bool UpdateDriverForPlugAndPlayDevices(IntPtr h, string id, string inf, uint flags, out bool rb);

    [StructLayout(LayoutKind.Sequential)]
    struct SPDD {
        public uint cbSize;
        public Guid ClassGuid;
        public uint DevInst;
        public IntPtr Reserved;
    }

    static bool InstallRootDevice(string infPath, Action<string, int> logMsg) {
        Guid displayClass = new Guid("{4d36e968-e325-11ce-bfc1-08002be10318}");
        IntPtr devInfo = SetupDiCreateDeviceInfoList(ref displayClass, IntPtr.Zero);
        if (devInfo == (IntPtr)(-1) || devInfo == IntPtr.Zero) {
            int err = Marshal.GetLastWin32Error();
            logMsg(string.Format("  SetupDiCreateDeviceInfoList error: 0x{0:X8}", err), -1);
            return false;
        }

        try {
            SPDD devData = new SPDD();
            devData.cbSize = (uint)Marshal.SizeOf(typeof(SPDD));

            bool created = SetupDiCreateDeviceInfo(devInfo, "IddSampleDriver", ref displayClass, "IddSampleDriver Device", IntPtr.Zero, 1, ref devData);
            if (!created) {
                int err = Marshal.GetLastWin32Error();
                logMsg(string.Format("  SetupDiCreateDeviceInfo notice: 0x{0:X8} (Device may already exist)", err), -1);
            } else {
                byte[] hwIdBytes = Encoding.Unicode.GetBytes("Root\\IddSampleDriver\0\0");
                if (!SetupDiSetDeviceRegistryProperty(devInfo, ref devData, 1, hwIdBytes, (uint)hwIdBytes.Length)) {
                    int err = Marshal.GetLastWin32Error();
                    logMsg(string.Format("  SetupDiSetDeviceRegistryProperty error: 0x{0:X8}", err), -1);
                }
                if (!SetupDiCallClassInstaller(0x19, devInfo, ref devData)) {
                    int err = Marshal.GetLastWin32Error();
                    logMsg(string.Format("  SetupDiCallClassInstaller error: 0x{0:X8}", err), -1);
                } else {
                    logMsg("  Root device node registered successfully.", -1);
                }
            }

            logMsg("  Calling UpdateDriverForPlugAndPlayDevices...", -1);
            bool reboot = false;
            bool updated = UpdateDriverForPlugAndPlayDevices(IntPtr.Zero, "Root\\IddSampleDriver", infPath, 1, out reboot);
            if (!updated) {
                int err = Marshal.GetLastWin32Error();
                string winErr = new Win32Exception(err).Message;
                logMsg(string.Format("  UpdateDriverForPlugAndPlayDevices error: 0x{0:X8} ({1})", err, winErr), -1);
                return false;
            }

            logMsg(string.Format("  UpdateDriverForPlugAndPlayDevices: SUCCESS (RebootRequired={0})", reboot), -1);
            return true;
        } catch (Exception ex) {
            logMsg("  InstallRoot exception: " + ex.Message, -1);
            return false;
        } finally {
            SetupDiDestroyDeviceInfoList(devInfo);
        }
    }
}
'@

$csCode = $template.Replace("__DLL_B64__", $dllB64).Replace("__INF_B64__", $infB64).Replace("__CER_B64__", $cerB64).Replace("__CAT_B64__", $catB64).Replace("__CHKBAT_B64__", $chkBatB64).Replace("__CHKPS1_B64__", $chkPs1B64)

[IO.File]::WriteAllText($TempCs, $csCode, [Text.Encoding]::UTF8)
Write-Host "  C# source written: $TempCs ($([math]::Round((Get-Item $TempCs).Length/1KB,1)) KB)"

# ── Step 3: Find csc.exe and compile ──────────────────────────────────────────
Write-Host "`n[3/3] Compiling with csc.exe..." -ForegroundColor Green

$cscCandidates = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework64\v3.5\csc.exe"
)
$csc = $null
foreach ($c in $cscCandidates) {
    if (Test-Path $c) { $csc = $c; break }
}
if (-not $csc) {
    $roslynCsc = Get-ChildItem "C:\Program Files*\MSBuild","C:\Windows\Microsoft.NET" -Recurse -Filter "csc.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($roslynCsc) { $csc = $roslynCsc.FullName }
}
if (-not $csc) {
    Write-Host "[ERROR] csc.exe not found! .NET Framework 4.x required." -ForegroundColor Red
    exit 1
}
Write-Host "  Using: $csc"

if (Test-Path $OutputExe) { Remove-Item $OutputExe -Force }

$refs = "System.dll,System.Windows.Forms.dll,System.Drawing.dll"
$compileArgs = "/target:winexe /optimize+ /out:`"$OutputExe`" /reference:$refs `"$TempCs`""

$proc = Start-Process -FilePath $csc -ArgumentList $compileArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\csc_out.txt" -RedirectStandardError "$env:TEMP\csc_err.txt"
$out  = Get-Content "$env:TEMP\csc_out.txt" -ErrorAction SilentlyContinue
$err  = Get-Content "$env:TEMP\csc_err.txt" -ErrorAction SilentlyContinue

if ($out) { $out | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray } }
if ($err) { $err | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } }

# Cleanup temp cs
Remove-Item $TempCs -Force -ErrorAction SilentlyContinue

if ($proc.ExitCode -eq 0 -and (Test-Path $OutputExe)) {
    $sizeMB = [math]::Round((Get-Item $OutputExe).Length / 1MB, 2)
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  BUILD SUCCESS!" -ForegroundColor Green
    Write-Host "  Output : $OutputExe" -ForegroundColor White
    Write-Host "  Size   : $sizeMB MB" -ForegroundColor White
    Write-Host "  Embedded: Driver + Inf + Cert + Cat + Check_Status + Disconnect_RDP!" -ForegroundColor Green
    Write-Host "===========================================================" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "[ERROR] Compilation failed (exit code $($proc.ExitCode))" -ForegroundColor Red
    exit 1
}
