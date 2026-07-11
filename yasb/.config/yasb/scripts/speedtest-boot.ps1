# Launched at logon via a shortcut in the Startup folder. Waits 5 minutes after
# logon, then waits for a working internet connection (up to ~5 more minutes) and,
# if online, runs the speedtest once. If no connectivity, it exits quietly
# without touching the cached result.
$ErrorActionPreference = 'SilentlyContinue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runScript = Join-Path $scriptDir 'speedtest-run.ps1'

# 5 minutes post-boot before doing anything.
Start-Sleep -Seconds 300

function Test-Internet {
    # TCP 443 to a highly-available host; avoids ICMP being blocked.
    (Test-NetConnection -ComputerName '1.1.1.1' -Port 443 -WarningAction SilentlyContinue).TcpTestSucceeded
}

$online = $false
for ($i = 0; $i -lt 30; $i++) {          # 30 tries x 10s = up to ~5 min
    if (Test-Internet) { $online = $true; break }
    Start-Sleep -Seconds 10
}

if ($online) {
    & $runScript
}
