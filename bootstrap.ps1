#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap this Windows machine from the dotfiles-win repo.

.DESCRIPTION
    - Installs dependencies with winget (PowerShell 7, oh-my-posh, ScreenToGif,
      Notepad++, FlowLauncher, WezTerm, Nerd Fonts).
    - Installs PowerShell modules from the Gallery (ZLocation, PSReadLine).
    - Writes a PowerShell 7 profile STUB (a plain file) that dot-sources the real
      profile in this repo — the $PROFILE lives in OneDrive, where symlinks sync badly.
    - Symlinks the remaining packages (FlowLauncher settings/themes, ~/.wslconfig,
      ~/.ssh/config) into their real, non-OneDrive locations.

    Symlinks need Windows Developer Mode ON or an elevated shell. The script probes
    this and skips the symlink packages cleanly if it can't (the profile stub, which
    needs no privilege, is still written). Replaced files are backed up to *.bak once.

.PARAMETER SkipInstall
    Only write the stub / create symlinks; skip winget and module installation.

.PARAMETER NoWork
    Personal machine: the stub sets $env:DOTFILES_SKIP_WORK so the profile does not
    load the TNP work-specific helpers (work.tnp.ps1).

.EXAMPLE
    .\bootstrap.ps1
.EXAMPLE
    .\bootstrap.ps1 -SkipInstall -NoWork
#>
[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$NoWork
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
#  Preconditions
# ---------------------------------------------------------------------------
function Test-DeveloperModeOrAdmin {
    $admin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent() `
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) { return $true }

    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    $devMode = (Get-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    return ($devMode -eq 1)
}

if (-not (Test-DeveloperModeOrAdmin)) {
    Write-Warn2 "Neither Developer Mode nor an elevated shell detected."
    Write-Warn2 "Enable Developer Mode (Settings > Privacy & security > For developers)"
    Write-Warn2 "or re-run this script from an elevated PowerShell, or symlink creation will fail."
}

# ---------------------------------------------------------------------------
#  Install dependencies
# ---------------------------------------------------------------------------
function Install-WingetApps {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn2 "winget not found; skipping app installs. Install 'App Installer' from the Store."
        return
    }
    $apps = @(
        'Microsoft.PowerShell',          # PowerShell 7 — the profile stub targets this
        'JanDeDobbeleer.OhMyPosh',
        'NickeManarin.ScreenToGif',
        'Notepad++.Notepad++',
        'Flow-Launcher.Flow-Launcher',
        'wez.wezterm',
        'AmN.yasb',
        'DEVCOM.JetBrainsMonoNerdFont'   # yasb uses "JetBrainsMono NFP"
    )
    foreach ($id in $apps) {
        $installed = winget list --id $id -e --accept-source-agreements 2>$null | Select-String -SimpleMatch $id
        if ($installed) {
            Write-Ok "$id already installed"
        } else {
            Write-Step "winget install $id"
            winget install --id $id -e --source winget `
                --accept-package-agreements --accept-source-agreements
        }
    }
}

function Install-NerdFonts {
    # These Nerd Fonts aren't on winget, so install them per-user from the
    # ryanoasis/nerd-fonts GitHub release. No admin required.
    #   - FiraCode  : wezterm's primary font
    #   - Symbols   : wezterm's explicit "Symbols Nerd Font Mono" glyph fallback
    $fonts = @(
        @{ Name = 'FiraCode Nerd Font';        Asset = 'FiraCode.zip';             Marker = 'FiraCode*NerdFont*.ttf' }
        @{ Name = 'Symbols Nerd Font';         Asset = 'NerdFontsSymbolsOnly.zip'; Marker = 'SymbolsNerdFont*.ttf' }
    )

    $fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
    $regPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    Add-Type -AssemblyName System.Drawing
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    foreach ($font in $fonts) {
        if (Get-ChildItem $fontsDir -Filter $font.Marker -ErrorAction SilentlyContinue) {
            Write-Ok "$($font.Name) already installed"
            continue
        }
        Write-Step "Installing $($font.Name) (per-user)"
        $tmp = Join-Path $env:TEMP "NF_$([System.IO.Path]::GetRandomFileName())"
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        try {
            $zip = Join-Path $tmp $font.Asset
            $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$($font.Asset)"
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
            Expand-Archive -Path $zip -DestinationPath $tmp -Force

            Get-ChildItem $tmp -Filter '*.ttf' -Recurse | ForEach-Object {
                $dest = Join-Path $fontsDir $_.Name
                Copy-Item $_.FullName $dest -Force
                $pfc = New-Object System.Drawing.Text.PrivateFontCollection
                $pfc.AddFontFile($dest)
                $family = $pfc.Families[0].Name
                $pfc.Dispose()
                Set-ItemProperty -Path $regPath -Name "$family (TrueType)" -Value $dest
            }
            Write-Ok "$($font.Name) installed"
        }
        catch {
            Write-Warn2 "$($font.Name) install failed: $($_.Exception.Message)"
        }
        finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-PSModules {
    foreach ($m in @('ZLocation', 'PSReadLine')) {
        if (Get-Module -ListAvailable -Name $m) {
            Write-Ok "module $m already available"
        } else {
            Write-Step "Install-Module $m"
            Install-Module $m -Scope CurrentUser -Force -AllowClobber
        }
    }
}

if (-not $SkipInstall) {
    Write-Step "Setting execution policy (CurrentUser -> RemoteSigned)"
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Install-WingetApps
    Install-NerdFonts
    Install-PSModules
} else {
    Write-Warn2 "-SkipInstall set; skipping winget + module installation."
}

# ---------------------------------------------------------------------------
#  Profile stub (PowerShell 7)
# ---------------------------------------------------------------------------
# The real $PROFILE lives in OneDrive-redirected Documents, where symlinks sync
# badly. So instead of symlinking, drop a tiny stub file there that dot-sources
# the real profile in this NTFS repo (everything else resolves via $PSScriptRoot).
function Write-ProfileStub {
    $docs       = [Environment]::GetFolderPath('MyDocuments')
    $ps7Profile = Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'
    $repoProfile = Join-Path $RepoRoot 'pwsh\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

    $lines = @(
        '# Auto-generated by dotfiles-win bootstrap.ps1 — do not edit.',
        '# Real profile lives in the dotfiles-win repo; this stub just loads it.'
    )
    if ($NoWork) { $lines += '$env:DOTFILES_SKIP_WORK = "1"   # personal machine: skip TNP work config' }
    $lines += ". `"$repoProfile`""
    $stub = ($lines -join "`r`n") + "`r`n"

    $dir = Split-Path $ps7Profile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if (Test-Path $ps7Profile) {
        $existing = Get-Content $ps7Profile -Raw -ErrorAction SilentlyContinue
        if ($existing -eq $stub) { Write-Ok "profile stub already in place: $ps7Profile"; return }
        $backup = "$ps7Profile.bak"
        if (-not (Test-Path $backup)) {
            Copy-Item $ps7Profile $backup
            Write-Warn2 "backed up existing profile -> $backup"
        }
    }
    Set-Content -Path $ps7Profile -Value $stub -Encoding UTF8 -NoNewline
    Write-Ok "wrote profile stub: $ps7Profile"
}

# ---------------------------------------------------------------------------
#  Symlink packages into place (stow-style)
# ---------------------------------------------------------------------------
# Probe whether this session can create symlinks (Developer Mode or elevated).
function Test-SymlinkCapability {
    $probe = Join-Path $env:TEMP "symprobe_$([IO.Path]::GetRandomFileName())"
    try {
        New-Item -ItemType SymbolicLink -Path $probe -Target $env:TEMP -ErrorAction Stop | Out-Null
        Remove-Item $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function New-Symlink {
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Dest
    )
    if (-not (Test-Path $Source)) {
        Write-Warn2 "source missing, skipped: $Source"
        return
    }
    $destDir = Split-Path -Parent $Dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    if (Test-Path $Dest) {
        $item = Get-Item $Dest -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            if ($item.Target -eq $Source) { Write-Ok "ok: $Dest"; return }
            Remove-Item $Dest -Force            # relink to new target
        } else {
            $backup = "$Dest.bak"
            if (-not (Test-Path $backup)) {
                Move-Item $Dest $backup
                Write-Warn2 "backed up existing $Dest -> $backup"
            } else {
                Remove-Item $Dest -Recurse -Force
            }
        }
    }
    New-Item -ItemType SymbolicLink -Path $Dest -Target $Source | Out-Null
    Write-Ok "linked: $Dest -> $Source"
}

Write-Step "Writing PowerShell 7 profile stub"
Write-ProfileStub

# Scaffold the gitignored TNP secrets file (Azure Bastion identifiers) if missing.
if (-not $NoWork) {
    $pwshDir    = Join-Path $RepoRoot 'pwsh\Documents\WindowsPowerShell'
    $tnpSecrets = Join-Path $pwshDir 'work.tnp.secrets.ps1'
    if (-not (Test-Path $tnpSecrets)) {
        Copy-Item (Join-Path $pwshDir 'work.tnp.secrets.example.ps1') $tnpSecrets
        Write-Warn2 "Created $tnpSecrets — fill in the TNP Bastion identifiers."
    }
}

# The remaining targets are outside OneDrive, so symlinks are safe there — but
# they still need symlink privilege. Probe once; skip cleanly if unavailable
# (nothing is moved/backed up unless we can actually create the link).
$canSymlink = Test-SymlinkCapability
if (-not $canSymlink) {
    Write-Warn2 "Symlink creation not permitted (enable Developer Mode or run elevated)."
    Write-Warn2 "Skipping FlowLauncher / WSL / SSH linking. Profile stub was still written."
} else {
    Write-Step "Linking FlowLauncher settings + themes"
    $flPkg    = Join-Path $RepoRoot 'flowlauncher\AppData\Roaming\FlowLauncher'
    $flTarget = Join-Path $env:APPDATA 'FlowLauncher'
    New-Symlink -Source (Join-Path $flPkg 'Settings\Settings.json') -Dest (Join-Path $flTarget 'Settings\Settings.json')
    Get-ChildItem -Path (Join-Path $flPkg 'Themes') -Filter *.xaml -Force | ForEach-Object {
        New-Symlink -Source $_.FullName -Dest (Join-Path $flTarget "Themes\$($_.Name)")
    }

    Write-Step "Linking yasb config"
    $yasbPkg    = Join-Path $RepoRoot 'yasb\.config\yasb'
    $yasbTarget = Join-Path $HOME '.config\yasb'
    foreach ($name in @('config.yaml', 'styles.css', 'todo.json', 'scripts', 'launchpad')) {
        New-Symlink -Source (Join-Path $yasbPkg $name) -Dest (Join-Path $yasbTarget $name)
    }
    # Secrets live in a gitignored .env (loaded by yasb). Scaffold it from the
    # template if missing, so config.yaml's $env: references resolve.
    $yasbEnv = Join-Path $yasbTarget '.env'
    if (-not (Test-Path $yasbEnv)) {
        Copy-Item (Join-Path $yasbPkg '.env.example') $yasbEnv
        Write-Warn2 "Created $yasbEnv — fill in YASB_WEATHER_API_KEY and YASB_GITHUB_TOKEN."
    }

    Write-Step "Linking WSL config"
    New-Symlink -Source (Join-Path $RepoRoot 'wsl\.wslconfig') -Dest (Join-Path $HOME '.wslconfig')

    Write-Step "Linking SSH config"
    New-Symlink -Source (Join-Path $RepoRoot 'ssh\.ssh\config') -Dest (Join-Path $HOME '.ssh\config')
    # Work-specific hosts live in a gitignored ~/.ssh/config.local (Included by config).
    $sshLocal = Join-Path $HOME '.ssh\config.local'
    if (-not $NoWork -and -not (Test-Path $sshLocal)) {
        Copy-Item (Join-Path $RepoRoot 'ssh\.ssh\config.local.example') $sshLocal
        Write-Warn2 "Created $sshLocal — add your work-specific SSH hosts."
    }
}

Write-Host ""
Write-Ok "Bootstrap complete. Open a new PowerShell 7 session to load the profile."
