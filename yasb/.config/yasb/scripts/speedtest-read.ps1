# Prints the cached speedtest result as JSON for the YASB custom widget.
# Must emit pure JSON on stdout with no BOM (json.loads is strict).
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$cache = Join-Path $env:LOCALAPPDATA 'yasb\speedtest.json'

if (Test-Path $cache) {
    [System.IO.File]::ReadAllText($cache)
} else {
    '{"text":"tap to test","down":"-","up":"-","ping":"-","status":"none"}'
}
