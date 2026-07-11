# =====================================================================
#  PowerShell profile  (portable — no hardcoded OneDrive paths)
#
#  This file is version-controlled in dotfiles-win and symlinked to the
#  real $PROFILE location by bootstrap.ps1. All paths resolve relative to
#  this script via $PSScriptRoot, so it works from wherever the repo lives.
# =====================================================================

# import generic helper functions
. "$PSScriptRoot/functions.ps1"

# import TNP work-specific helpers only if present (kept out of the personal set).
# The bootstrap stub sets $env:DOTFILES_SKIP_WORK on personal machines (-NoWork).
if (-not $env:DOTFILES_SKIP_WORK -and (Test-Path "$PSScriptRoot/work.tnp.ps1")) {
    . "$PSScriptRoot/work.tnp.ps1"
}

# oh-my-posh prompt theme
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh --init --shell pwsh --config "$PSScriptRoot/my-theme.omp.json" | Invoke-Expression
}

# modules (installed from the PowerShell Gallery by bootstrap.ps1)
Import-Module ZLocation -ErrorAction SilentlyContinue
Import-Module PSReadLine -ErrorAction SilentlyContinue

# Chocolatey tab-completion (no-op if choco isn't installed)
$ChocolateyProfile = "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# --------------------------------------------------------------------
#  App aliases
# --------------------------------------------------------------------
# gifify -> ScreenToGif (installed via winget, resolved from PATH)
if (Get-Command ScreenToGif -ErrorAction SilentlyContinue) {
    Set-Alias gifify ScreenToGif
}

# Notepad++
Set-Alias npp       Launch-NotepadPlusPlus
Set-Alias edit-hosts Open-HostsFile

# nano text editor (installed via winget/choco; falls back to legacy ~/.nano path)
if (Get-Command nano -ErrorAction SilentlyContinue) {
    # nano already on PATH
} elseif (Test-Path "$HOME/.nano/nano.exe") {
    Set-Alias nano "$HOME/.nano/nano.exe"
}

# --------------------------------------------------------------------
#  Explorer navigation aliases
# --------------------------------------------------------------------
Set-Alias home      Go-Home
Set-Alias repos     Go-Repos
Set-Alias downloads Go-Downloads
Set-Alias profile   Go-Profile

# --------------------------------------------------------------------
#  Python / venv aliases
# --------------------------------------------------------------------
Set-Alias -Name activate-env -Value "./.venv/Scripts/activate"
Set-Alias activate-tnp-atlas "./.venv/tnp-atlas/Scripts/activate"
Set-Alias req2poetry      Requirements-To-Poetry
Set-Alias pip-purge       Uninstall-AllPipPackages

# --------------------------------------------------------------------
#  Misc / shell aliases
# --------------------------------------------------------------------
Set-Alias touch       mkfile
Set-Alias which       Get-Command
Set-Alias undo-commit Undo-LastCommit
Set-Alias wsl-restart Restart-WSL
