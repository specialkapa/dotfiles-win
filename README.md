# dotfiles-win

My **Windows** dotfiles. These files live on NTFS and are consumed by Windows apps, so
[bootstrap.ps1](./bootstrap.ps1) wires them up with a plain **stub** for the PowerShell profile, and
**symlinks** for the rest.

## Packages

| Package        | Wired into                                       | How           | What it is                                                   |
| -------------- | ------------------------------------------------ | ------------- | ------------------------------------------------------------ |
| `pwsh`         | PowerShell 7 `$PROFILE` (`Documents\PowerShell`) | **stub file** | PowerShell profile, functions, theme, helper scripts         |
| `flowlauncher` | `%APPDATA%\FlowLauncher`                         | symlink       | FlowLauncher `Settings.json` + custom themes                 |
| `yasb`         | `~\.config\yasb`                                 | symlink       | yasb status bar config, styles, scripts (secrets via `.env`) |
| `wsl`          | `~\.wslconfig`                                   | symlink       | WSL2 resource limits                                         |
| `ssh`          | `~\.ssh\config`                                  | symlink       | SSH host config (no keys)                                    |

The profile uses a **stub** rather than a symlink because the real `$PROFILE` lives in
OneDrive-redirected `Documents`, where OneDrive syncs symlinks badly. The stub is a plain one-line
file that dot-sources the real profile in this repo (which resolves everything else via
`$PSScriptRoot`). The other three targets are outside OneDrive, so they symlink.

The PowerShell profile is split:

- **[functions.ps1](./pwsh/Documents/WindowsPowerShell/functions.ps1)**: generic, machine-agnostic
  helpers + aliases.
- **[work.tnp.ps1)[./pwsh/Documents/WindowsPowerShell/work.tnp.ps1]**: TNP-specific shortcuts
  (Atlas, CMAP, PayWindow, TNP GitHub, Azure Bastion). Loaded **only if present**, so personal
  machines can skip it with `bootstrap.ps1 -NoWork`.

All internal paths use `$PSScriptRoot`, so the profile runs from wherever the repo lives.

## Bootstrap a new machine

Prerequisites: Windows 10/11 with **winget**, and **Developer Mode ON** (Settings > Privacy &
security > For developers) so symlinks can be created without elevation. (`PowerShell` 7 itself is
installed by the script.)

```powershell
git clone <this-repo-url> $HOME\repos\dotfiles-win
cd $HOME\repos\dotfiles-win
# add -NoWork on a personal machine
.\bootstrap.ps1
```

`bootstrap.ps1`:

1. Sets execution policy (`CurrentUser` to `RemoteSigned`).
2. `winget install`s: `PowerShell` 7, `oh-my-posh`, `ScreenToGif`, `Notepad+`+, `FlowLauncher`,
   `WezTerm`, `yasb` and JetBrainsMono Nerd Font.
3. Installs **FiraCode** + **Symbols** Nerd Fonts per-user from the Nerd Fonts GitHub release (not
   on winget).
4. `Install-Module`s `ZLocation` and `PSReadLine` from the `PowerShell` Gallery.
5. Writes the `PowerShell `7 profile **stub**, then symlinks `FlowLauncher `/ WSL / SSH configs
   (backing up any existing real file to `*.bak` once).

Symlink creation needs Developer Mode; the script probes for it and **skips the symlink packages
cleanly if it's off**. The profile stub is written regardless. Enable Developer Mode and re-run to
finish the symlinks.

Open a new `PowerShell` 7 session afterwards to load the profile.

Use `.\bootstrap.ps1 -SkipInstall` to only (re)write the stub + symlinks.

## Secrets

Nothing secret is committed. yasb's weather API key and GitHub token are referenced from
`config.yaml` as `$env:YASB_WEATHER_API_KEY` / `$env:YASB_GITHUB_TOKEN` and live in a **gitignored**
`~/.config/yasb/.env`. Bootstrap scaffolds that file from `.env.example`; fill in real values there.

## Notes

`WezTerm` reads its config from the WSL `~/.dotfiles` via a generated `~/.wezterm.lua` loader run
`~/.dotfiles/wezterm/install-windows-loader.sh` from WSL after installing `WezTerm`.
