# ==============================================================================
# build_setup.ps1 - Builds a single self-contained Setup.exe
# Embeds: IddSampleDriver.dll, .inf, .cer, .cat inside the EXE
# Uses csc.exe (built-in .NET C# compiler) — No external tools needed
# ==============================================================================

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$DriverDir  = Join-Path $ScriptDir "IddSampleDriver"
$ReleaseDir = Join-Path $ScriptDir "Release"
$OutputExe  = Join-Path $ReleaseDir "Setup.exe"
$TempCs     = Join-Path $env:TEMP "DSVirtualDisplay_Setup.cs"

Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  DSVirtualDisplay - Single EXE Builder" -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan

# Ensure Release dir
if (-not (Test-Path $ReleaseDir)) { New-Item -ItemType Directory -Path $ReleaseDir | Out-Null }

# ── Step 1: Encode driver files as Base64 ─────────────────────────────────────
Write-Host "`n[1/3] Embedding driver files..." -ForegroundColor Green

$filePaths = @{
    DLL = Join-Path $DriverDir "IddSampleDriver.dll"
    INF = Join-Path $DriverDir "IddSampleDriver.inf"
    CER = Join-Path $DriverDir "iddsampledriver.cer"
    CAT = Join-Path $DriverDir "iddsampledriver.cat"
}

foreach ($kv in $filePaths.GetEnumerator()) {
    if (-not (Test-Path $kv.Value)) {
        Write-Host "[ERROR] Missing: $($kv.Value)" -ForegroundColor Red
        exit 1
    }
}

$dllB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.DLL))
$infB64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.INF))
$cerB64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.CER))
$catB64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePaths.CAT))

Write-Host "  DLL : $([math]::Round($dllB64.Length*3/4/1KB,1)) KB"
Write-Host "  INF : $([math]::Round($infB64.Length*3/4/1KB,1)) KB"
Write-Host "  CER : $([math]::Round($cerB64.Length*3/4/1KB,1)) KB"
Write-Host "  CAT : $([math]::Round($catB64.Length*3/4/1KB,1)) KB"

# ── Step 2: Write C# source file ──────────────────────────────────────────────
Write-Host "`n[2/3] Generating C# source..." -ForegroundColor Green

$csLines = @()
$csLines += 'using System;'
$csLines += 'using System.Collections.Generic;'
$csLines += 'using System.Diagnostics;'
$csLines += 'using System.Drawing;'
$csLines += 'using System.IO;'
$csLines += 'using System.Runtime.InteropServices;'
$csLines += 'using System.Security.Principal;'
$csLines += 'using System.Text;'
$csLines += 'using System.Windows.Forms;'
$csLines += 'using Microsoft.Win32;'
$csLines += ''
$csLines += 'static class Program {'
$csLines += '    [STAThread]'
$csLines += '    static void Main() {'
$csLines += '        if (!new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)) {'
$csLines += '            try { Process.Start(new ProcessStartInfo(System.Reflection.Assembly.GetExecutingAssembly().Location) { Verb = "runas", UseShellExecute = true }); } catch {}'
$csLines += '            return;'
$csLines += '        }'
$csLines += '        Application.EnableVisualStyles();'
$csLines += '        Application.SetCompatibleTextRenderingDefault(false);'
$csLines += '        int n = ShowMonitorDialog();'
$csLines += '        if (n < 1) return;'
$csLines += '        ShowInstallForm(n);'
$csLines += '    }'
$csLines += ''
$csLines += '    static int ShowMonitorDialog() {'
$csLines += '        Color bg   = Color.FromArgb(28,28,38);'
$csLines += '        Color blue = Color.FromArgb(0,120,215);'
$csLines += '        Color txt  = Color.FromArgb(220,220,230);'
$csLines += '        Color sub  = Color.FromArgb(160,160,175);'
$csLines += '        Form f = new Form { Text="Virtual Display Driver - Setup", Size=new Size(440,370),'
$csLines += '            StartPosition=FormStartPosition.CenterScreen, FormBorderStyle=FormBorderStyle.FixedDialog,'
$csLines += '            MaximizeBox=false, MinimizeBox=false, BackColor=bg };'
$csLines += '        f.Controls.Add(new Label { Text="Virtual Monitor Setup",'
$csLines += '            Font=new Font("Segoe UI",15,FontStyle.Bold), ForeColor=Color.FromArgb(90,190,255),'
$csLines += '            Location=new Point(20,20), Size=new Size(390,32), BackColor=Color.Transparent });'
$csLines += '        f.Controls.Add(new Label { Text="Aap kitne Virtual Monitors banana chahte hain?",'
$csLines += '            Font=new Font("Segoe UI",9), ForeColor=sub,'
$csLines += '            Location=new Point(22,58), Size=new Size(390,20), BackColor=Color.Transparent });'
$csLines += '        f.Controls.Add(new Panel { Location=new Point(20,84), Size=new Size(390,1), BackColor=Color.FromArgb(55,55,72) });'
$csLines += '        string[] opts = { "  1 Virtual Monitor   (Recommended / Default)","  2 Virtual Monitors","  3 Virtual Monitors","  4 Virtual Monitors","  5 Virtual Monitors" };'
$csLines += '        RadioButton[] rbs = new RadioButton[5];'
$csLines += '        for (int i=0;i<5;i++) {'
$csLines += '            rbs[i]=new RadioButton { Text=opts[i], Font=new Font("Segoe UI",10), ForeColor=txt,'
$csLines += '                BackColor=Color.Transparent, Location=new Point(26,96+i*36), Size=new Size(380,30),'
$csLines += '                Checked=(i==0), Cursor=Cursors.Hand };'
$csLines += '            f.Controls.Add(rbs[i]);'
$csLines += '        }'
$csLines += '        Button ok = new Button { Text="  Install Now", Font=new Font("Segoe UI",10,FontStyle.Bold),'
$csLines += '            ForeColor=Color.White, BackColor=blue, FlatStyle=FlatStyle.Flat,'
$csLines += '            Location=new Point(20,292), Size=new Size(185,40), Cursor=Cursors.Hand, DialogResult=DialogResult.OK };'
$csLines += '        ok.FlatAppearance.BorderSize=0; f.Controls.Add(ok); f.AcceptButton=ok;'
$csLines += '        Button cn = new Button { Text="  Cancel", Font=new Font("Segoe UI",10),'
$csLines += '            ForeColor=sub, BackColor=Color.FromArgb(58,58,72), FlatStyle=FlatStyle.Flat,'
$csLines += '            Location=new Point(225,292), Size=new Size(185,40), Cursor=Cursors.Hand, DialogResult=DialogResult.Cancel };'
$csLines += '        cn.FlatAppearance.BorderSize=0; f.Controls.Add(cn); f.CancelButton=cn;'
$csLines += '        if (f.ShowDialog()!=DialogResult.OK) return -1;'
$csLines += '        for (int i=0;i<5;i++) if(rbs[i].Checked) return i+1;'
$csLines += '        return 1;'
$csLines += '    }'
$csLines += ''
$csLines += '    static void ShowInstallForm(int count) {'
$csLines += '        Color bg  = Color.FromArgb(28,28,38);'
$csLines += '        Color txt = Color.FromArgb(220,220,230);'
$csLines += '        Color grn = Color.FromArgb(80,200,100);'
$csLines += '        Color sub = Color.FromArgb(160,160,175);'
$csLines += '        Form pf = new Form { Text="Installing...", Size=new Size(460,310),'
$csLines += '            StartPosition=FormStartPosition.CenterScreen, FormBorderStyle=FormBorderStyle.FixedDialog,'
$csLines += '            MaximizeBox=false, MinimizeBox=false, BackColor=bg };'
$csLines += '        Label lbl = new Label { Text="Installing Virtual Display Driver...",'
$csLines += '            Font=new Font("Segoe UI",11,FontStyle.Bold), ForeColor=Color.FromArgb(90,190,255),'
$csLines += '            Location=new Point(20,18), Size=new Size(410,28), BackColor=Color.Transparent };'
$csLines += '        pf.Controls.Add(lbl);'
$csLines += '        ProgressBar pb = new ProgressBar { Location=new Point(20,55), Size=new Size(410,18),'
$csLines += '            Minimum=0, Maximum=100, Value=0, Style=ProgressBarStyle.Continuous };'
$csLines += '        pf.Controls.Add(pb);'
$csLines += '        ListBox log = new ListBox { Location=new Point(20,84), Size=new Size(410,150),'
$csLines += '            BackColor=Color.FromArgb(20,20,30), ForeColor=txt,'
$csLines += '            Font=new Font("Consolas",8), BorderStyle=BorderStyle.None };'
$csLines += '        pf.Controls.Add(log);'
$csLines += '        Button bc = new Button { Text="Close", Font=new Font("Segoe UI",9),'
$csLines += '            ForeColor=sub, BackColor=Color.FromArgb(50,50,65), FlatStyle=FlatStyle.Flat,'
$csLines += '            Location=new Point(340,248), Size=new Size(90,32), Enabled=false, Cursor=Cursors.Hand };'
$csLines += '        bc.FlatAppearance.BorderSize=0; bc.Click+=(s,e)=>pf.Close(); pf.Controls.Add(bc);'
$csLines += '        pf.Show(); Application.DoEvents();'
$csLines += '        Action<string,int> upd=(msg,pct)=>{'
$csLines += '            log.Items.Add(msg); log.TopIndex=log.Items.Count-1; pb.Value=pct; Application.DoEvents(); };'
$csLines += '        bool ok=false;'
$csLines += '        try {'
$csLines += '            upd("Extracting embedded driver files...",10);'
$csLines += '            string tmp=Path.Combine(Path.GetTempPath(),"DSVDisp_"+Guid.NewGuid().ToString("N").Substring(0,8));'
$csLines += '            Directory.CreateDirectory(tmp);'
$csLines += '            string dll=Path.Combine(tmp,"IddSampleDriver.dll");'
$csLines += '            string inf=Path.Combine(tmp,"IddSampleDriver.inf");'
$csLines += '            string cer=Path.Combine(tmp,"iddsampledriver.cer");'
$csLines += '            string cat=Path.Combine(tmp,"iddsampledriver.cat");'
$csLines += '            File.WriteAllBytes(dll,Convert.FromBase64String(EmbeddedDll));'
$csLines += '            File.WriteAllBytes(inf,Convert.FromBase64String(EmbeddedInf));'
$csLines += '            File.WriteAllBytes(cer,Convert.FromBase64String(EmbeddedCer));'
$csLines += '            File.WriteAllBytes(cat,Convert.FromBase64String(EmbeddedCat));'
$csLines += '            upd("  OK: Files extracted.",20);'
$csLines += '            upd("Writing display configuration...",30);'
$csLines += '            string cfgDir=@"C:\IddSampleDriver"; string cfgFile=cfgDir+@"\option.txt";'
$csLines += '            if(!Directory.Exists(cfgDir)) Directory.CreateDirectory(cfgDir);'
$csLines += '            string dllDest=Path.Combine(cfgDir,"IddSampleDriver.dll"); File.Copy(dll,dllDest,true);'
$csLines += '            var resLines=new List<string>{ count.ToString(),'
$csLines += '                " 640,  480, 60"," 800,  600, 60","1024,  768, 60","1280,  720, 60","1280,  800, 60",'
$csLines += '                "1280, 1024, 60","1366,  768, 60","1440,  900, 60","1600,  900, 60","1920, 1080, 60",'
$csLines += '                "1920, 1200, 60","2560, 1440, 60","2560, 1600, 60","3840, 2160, 60","4096, 2160, 60" };'
$csLines += '            File.WriteAllLines(cfgFile,resLines.ToArray());'
$csLines += '            Environment.SetEnvironmentVariable("IDD_SAMPLE_DRIVER_CONFIG",cfgFile,EnvironmentVariableTarget.Machine);'
$csLines += '            string rdpBat = "@echo off\r\nnet session >nul 2>&1\r\nif %errorlevel% neq 0 ( powershell -NoProfile -Command \"\"Start-Process -FilePath ''%~f0'' -Verb RunAs\"\" & exit /b )\r\necho Transferring RDP session to Virtual Display (Console)...\r\npowershell -NoProfile -Command \"\"$s=(Get-Process -Id $PID).SessionId; & tscon.exe $s /dest:console\"\"\r\n";'
$csLines += '            File.WriteAllText(Path.Combine(cfgDir,"Disconnect_RDP.bat"), rdpBat);'
$csLines += '            try { string d1=Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory); if(!string.IsNullOrEmpty(d1)&&Directory.Exists(d1)) File.WriteAllText(Path.Combine(d1,"Disconnect_RDP.bat"), rdpBat); } catch {}'
$csLines += '            try { string d2=Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory); if(!string.IsNullOrEmpty(d2)&&Directory.Exists(d2)) File.WriteAllText(Path.Combine(d2,"Disconnect_RDP.bat"), rdpBat); } catch {}'
$csLines += '            upd(string.Format("  OK: {0} monitor(s) configured + Disconnect_RDP placed on Desktop.",count),40);'
$csLines += '            upd("Applying registry settings (WDDM & Anti-Blackscreen)...",50);'
$csLines += '            ApplyReg();'
$csLines += '            upd("  OK: Registry done.",58);'
$csLines += '            upd("Installing certificate...",65);'
$csLines += '            Cmd("certutil.exe",string.Format("-addstore -f Root \"{0}\"",cer));'
$csLines += '            Cmd("certutil.exe",string.Format("-addstore -f TrustedPublisher \"{0}\"",cer));'
$csLines += '            upd("  OK: Certificate trusted.",72);'
$csLines += '            upd("Installing driver...",78);'
$csLines += '            string pnp=Cmd("pnputil.exe","/enum-devices /class Display");'
$csLines += '            if(pnp!=null && pnp.IndexOf("IddSample",StringComparison.OrdinalIgnoreCase)>=0) {'
$csLines += '                upd("  Reloading existing driver...",84);'
$csLines += '                Cmd("pnputil.exe",@"/restart-device /deviceid ""Root\IddSampleDriver""");'
$csLines += '            } else {'
$csLines += '                Cmd("pnputil.exe",string.Format("/add-driver \"{0}\" /install",inf));'
$csLines += '                InstallRoot(inf);'
$csLines += '            }'
$csLines += '            Cmd("pnputil.exe","/scan-devices");'
$csLines += '            upd("  OK: Driver installed.",95);'
$csLines += '            try{Directory.Delete(tmp,true);}catch{}'
$csLines += '            ok=true; upd(string.Format("SUCCESS! {0} Virtual Monitor(s) ready.",count),100);'
$csLines += '        } catch(Exception ex) { upd("ERROR: "+ex.Message, pb.Value); }'
$csLines += '        lbl.Text = ok ? string.Format("+ {0} Monitor(s) installed successfully!",count) : "- Installation failed!";'
$csLines += '        lbl.ForeColor = ok ? grn : Color.FromArgb(255,80,80);'
$csLines += '        bc.Enabled=true; bc.BackColor=Color.FromArgb(0,120,215); bc.ForeColor=Color.White;'
$csLines += '        Application.Run(pf);'
$csLines += '    }'
$csLines += ''
$csLines += '    static void ApplyReg() {'
$csLines += '        foreach(string k in new[]{'
$csLines += '            @"SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services",'
$csLines += '            @"SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations",'
$csLines += '            @"SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"}) {'
$csLines += '            RegistryKey rk=Registry.LocalMachine.OpenSubKey(k,true)??Registry.LocalMachine.CreateSubKey(k);'
$csLines += '            if(rk==null) continue;'
$csLines += '            rk.SetValue("fEnableWddmDriver",1,RegistryValueKind.DWord);'
$csLines += '            rk.SetValue("EnableWddmDriver",1,RegistryValueKind.DWord);'
$csLines += '            rk.SetValue("bEnUserSettings",1,RegistryValueKind.DWord);'
$csLines += '            rk.SetValue("fEnableHardwareMode",1,RegistryValueKind.DWord);'
$csLines += '            rk.SetValue("MaxDisconnectionTime",0,RegistryValueKind.DWord);'
$csLines += '            rk.SetValue("MaxIdleTime",0,RegistryValueKind.DWord);'
$csLines += '            rk.Close();'
$csLines += '        }'
$csLines += '        foreach(string k in new[]{@"SOFTWARE\Microsoft\Terminal Server Client",@"SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client"}) {'
$csLines += '            try { RegistryKey rk=Registry.LocalMachine.OpenSubKey(k,true)??Registry.LocalMachine.CreateSubKey(k); if(rk!=null){ rk.SetValue("RemoteDesktop_SuppressWhenMinimized",2,RegistryValueKind.DWord); rk.Close(); } } catch {}'
$csLines += '            try { RegistryKey rku=Registry.CurrentUser.OpenSubKey(k,true)??Registry.CurrentUser.CreateSubKey(k); if(rku!=null){ rku.SetValue("RemoteDesktop_SuppressWhenMinimized",2,RegistryValueKind.DWord); rku.Close(); } } catch {}'
$csLines += '        }'
$csLines += '        try { Cmd("sc.exe","config TeamViewer start= auto"); Cmd("net.exe","start TeamViewer"); } catch {}'
$csLines += '    }'
$csLines += ''
$csLines += '    static string Cmd(string exe,string args) {'
$csLines += '        try { var p=new Process{StartInfo=new ProcessStartInfo(exe,args){'
$csLines += '            RedirectStandardOutput=true,UseShellExecute=false,CreateNoWindow=true}};'
$csLines += '            p.Start(); string o=p.StandardOutput.ReadToEnd(); p.WaitForExit(15000); return o;'
$csLines += '        } catch { return null; }'
$csLines += '    }'
$csLines += ''
$csLines += '    [DllImport("setupapi.dll",SetLastError=true,CharSet=CharSet.Auto)]'
$csLines += '    static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid g,IntPtr h);'
$csLines += '    [DllImport("setupapi.dll",SetLastError=true,CharSet=CharSet.Auto)]'
$csLines += '    static extern bool SetupDiCreateDeviceInfo(IntPtr s,string n,ref Guid g,string d,IntPtr h,uint f,ref SPDD dd);'
$csLines += '    [DllImport("setupapi.dll",SetLastError=true,CharSet=CharSet.Auto)]'
$csLines += '    static extern bool SetupDiSetDeviceRegistryProperty(IntPtr s,ref SPDD d,uint p,byte[] b,uint sz);'
$csLines += '    [DllImport("setupapi.dll",SetLastError=true,CharSet=CharSet.Auto)]'
$csLines += '    static extern bool SetupDiCallClassInstaller(uint f,IntPtr s,ref SPDD d);'
$csLines += '    [DllImport("setupapi.dll",SetLastError=true)]'
$csLines += '    static extern bool SetupDiDestroyDeviceInfoList(IntPtr s);'
$csLines += '    [DllImport("newdev.dll",SetLastError=true,CharSet=CharSet.Auto)]'
$csLines += '    static extern bool UpdateDriverForPlugAndPlayDevices(IntPtr h,string id,string inf,uint flags,out bool rb);'
$csLines += '    [StructLayout(LayoutKind.Sequential)]'
$csLines += '    struct SPDD { public uint cbSize; public Guid ClassGuid; public uint DevInst; public IntPtr Reserved; }'
$csLines += ''
$csLines += '    static void InstallRoot(string inf) {'
$csLines += '        try {'
$csLines += '            Guid dc=new Guid("{4d36e968-e325-11ce-bfc1-08002be10318}");'
$csLines += '            IntPtr ds=SetupDiCreateDeviceInfoList(ref dc,IntPtr.Zero);'
$csLines += '            if(ds==(IntPtr)(-1)) return;'
$csLines += '            SPDD dd=new SPDD{cbSize=(uint)Marshal.SizeOf(typeof(SPDD))};'
$csLines += '            if(!SetupDiCreateDeviceInfo(ds,"IddSampleDriver",ref dc,"IddSampleDriver Device",IntPtr.Zero,1,ref dd)){SetupDiDestroyDeviceInfoList(ds);return;}'
$csLines += '            byte[] hw=Encoding.Unicode.GetBytes(@"Root\IddSampleDriver"+"\0\0");'
$csLines += '            SetupDiSetDeviceRegistryProperty(ds,ref dd,1,hw,(uint)hw.Length);'
$csLines += '            SetupDiCallClassInstaller(0x19,ds,ref dd);'
$csLines += '            bool rb; UpdateDriverForPlugAndPlayDevices(IntPtr.Zero,@"Root\IddSampleDriver",inf,1,out rb);'
$csLines += '            SetupDiDestroyDeviceInfoList(ds);'
$csLines += '        } catch {}'
$csLines += '    }'
$csLines += ''

# Inject Base64 constants (split into lines to avoid PowerShell string length issues)
$csLines += "    const string EmbeddedDll = `"$dllB64`";"
$csLines += "    const string EmbeddedInf = `"$infB64`";"
$csLines += "    const string EmbeddedCer = `"$cerB64`";"
$csLines += "    const string EmbeddedCat = `"$catB64`";"
$csLines += '}'

[IO.File]::WriteAllLines($TempCs, $csLines, [Text.Encoding]::UTF8)
Write-Host "  C# source written: $TempCs ($([math]::Round((Get-Item $TempCs).Length/1KB,1)) KB)"

# ── Step 3: Find csc.exe and compile ──────────────────────────────────────────
Write-Host "`n[3/3] Compiling with csc.exe..." -ForegroundColor Green

# Find csc.exe - search common .NET Framework locations
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
    # Try vswhere / Roslyn
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
    Write-Host "  Single EXE - No DLL, No INF, No CER, No config file!" -ForegroundColor Green
    Write-Host "===========================================================" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "[ERROR] Compilation failed (exit code $($proc.ExitCode))" -ForegroundColor Red
    exit 1
}
