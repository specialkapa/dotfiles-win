# Runs the Ookla Speedtest CLI and writes the result as JSON for the YASB
# custom widget. The CLI is downloaded once and cached under %LOCALAPPDATA%\yasb.
# Intended to be fired from the widget's on_left callback (runs hidden).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest fast

$appDir = Join-Path $env:LOCALAPPDATA 'yasb'
$cliDir = Join-Path $appDir 'speedtest-cli'
$exe    = Join-Path $cliDir 'speedtest.exe'
$cache  = Join-Path $appDir 'speedtest.json'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Cache([hashtable]$data) {
    $json = [ordered]@{
        text   = $data.text
        down   = "$($data.down)"
        up     = "$($data.up)"
        ping   = "$($data.ping)"
        status = $data.status
    } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($cache, $json, $utf8NoBom)
}

try {
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null

    # Immediate feedback while the test runs.
    Write-Cache @{ text = 'testing...'; down = '-'; up = '-'; ping = '-'; status = 'running' }

    # Download + cache the Ookla CLI on first use.
    if (-not (Test-Path $exe)) {
        $page = Invoke-WebRequest -Uri 'https://www.speedtest.net/apps/cli' -UseBasicParsing
        if ($page.Content -match 'href="(https://install\.speedtest\.net/app/cli/ookla-speedtest-[\d\.]+-win64\.zip)"') {
            $link = $matches[1]
        } else {
            throw 'Could not find Ookla CLI download link.'
        }
        $zip = Join-Path $env:TEMP 'ookla-speedtest.zip'
        Invoke-WebRequest -Uri $link -OutFile $zip -UseBasicParsing
        if (Test-Path $cliDir) { Remove-Item $cliDir -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $cliDir -Force
        Remove-Item $zip -Force
    }

    # Run the test with machine-readable output. Relax error handling around the
    # native call: the CLI writes progress to stderr, which throws under 'Stop'.
    $ErrorActionPreference = 'Continue'
    $raw = & $exe --accept-license --accept-gdpr --format=json 2>$null | Out-String
    $ErrorActionPreference = 'Stop'
    $r = $raw | ConvertFrom-Json

    # Ookla reports bandwidth in bytes/sec; Mbps = bytes * 8 / 1e6.
    $down = [math]::Round($r.download.bandwidth * 8 / 1000000)
    $up   = [math]::Round($r.upload.bandwidth   * 8 / 1000000)
    $ping = [math]::Round($r.ping.latency)

    # U+2193 down arrow (download), U+2191 up arrow (upload).
    $text = "{0}{1} {2}{3} Mbps" -f [char]0x2193, $down, [char]0x2191, $up
    Write-Cache @{ text = $text; down = $down; up = $up; ping = $ping; status = 'ok' }
} catch {
    "$(Get-Date -Format o)  $($_.Exception.Message)`n$($_.InvocationInfo.PositionMessage)" |
        Out-File -FilePath (Join-Path $appDir 'speedtest-error.log') -Encoding utf8
    Write-Cache @{ text = 'test failed'; down = '-'; up = '-'; ping = '-'; status = 'error' }
}
