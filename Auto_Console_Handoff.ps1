# ==============================================================================
# Auto_Console_Handoff.ps1 - Automatically transfer disconnected RDP to Console
# Ensures UltraViewer / TeamViewer / AnyDesk never freeze when [X] is pressed.
# ==============================================================================
$logFile = "C:\IddSampleDriver\autounlock.log"

function Write-Log([string]$msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $msg" -ErrorAction SilentlyContinue
}

Write-Log "Auto-Unlock triggered."

# Brief pause to let Windows finish session state change
Start-Sleep -Seconds 1

$disconnectedSession = $null

for ($attempt = 1; $attempt -le 3; $attempt++) {
    $lines = & query session 2>&1

    foreach ($line in $lines) {
        # Match only lines where state is Disc, e.g. " 2 Disc"
        if ($line -match "\s+(\d+)\s+Disc\b") {
            $sid = [int]$Matches[1]
            if ($sid -gt 0) {
                $disconnectedSession = $sid
                break
            }
        }
    }

    if ($disconnectedSession) {
        break
    }
    Start-Sleep -Seconds 1
}

if ($disconnectedSession) {
    Write-Log "Found disconnected session ID: $disconnectedSession. Transferring to console..."
    $tsconPath = "$env:windir\System32\tscon.exe"
    $output = & $tsconPath $disconnectedSession /dest:console 2>&1
    Write-Log "tscon executed with result: $($output -join ' ')"
} else {
    Write-Log "No disconnected session found (session is active or already on console). No action taken."
}
