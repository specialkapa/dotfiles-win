Write-Host ""
Write-Host ""
Write-Host -ForegroundColor Yellow -NoNewline "INFO   : "
Write-Host "Fetching IP of WSL instance ..."

$hostname = "wsl"

# find ip of eth0
$ifconfig = (wsl -- ip -4 addr show eth0)
$ipPattern = "((\d+\.?){4})"
$ip = ([regex]"inet $ipPattern").Match($ifconfig).Groups[1].Value
if (-not $ip) {
    exit
}
Write-Host -ForegroundColor Green -NoNewline "SUCCESS: "
Write-Host "WSL instance IP: $ip"

$hostsPath = "$env:windir/system32/drivers/etc/hosts"

$hosts = (Get-Content -Path $hostsPath -Raw -ErrorAction Ignore)
if ($null -eq $hosts) {
    $hosts = ""
}
$hosts = $hosts.Trim()

# update or add wsl ip
$find = "$ipPattern\s+$hostname"
$entry = "$ip $hostname"

if ($hosts -match $find) {
    $hosts = $hosts -replace $find, $entry
}
else {
    $hosts = "$hosts`n$entry".Trim()
}

Write-Host -ForegroundColor Yellow -NoNewline "INFO   : "
Write-Host "Updating $hostsPath file ..."
try {
    $temp = "$hostsPath.new"
    New-Item -Path $temp -ItemType File -Force | Out-Null
    Set-Content -Path $temp $hosts

    Move-Item -Path $temp -Destination $hostsPath -Force
	Write-Host -ForegroundColor Green -NoNewline "SUCCESS: "
	Write-Host "Done!"
}
catch {
    Write-Error -ForegroundColor Red "Cannot update WSL IP address!"
}