# Generic, machine-agnostic helper functions imported by the profile.
# TNP work-specific helpers live in work.tnp.ps1 (loaded only if present).

# -------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------ NotepadPlusPlus --------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

# function to open any file with notepad++
function Launch-NotepadPlusPlus ($filePath) {
    $notepadppPath = "C:\Program Files\Notepad++\notepad++.exe"
    if (Test-Path $notepadppPath) {
        Start-Process $notepadppPath -ArgumentList $filePath
    } else {
        Write-Host "Notepad++ not found at $notepadppPath"
    }
    Start-Sleep -Milliseconds 300
}

function Open-HostsFile {
    Launch-NotepadPlusPlus C:\Windows\System32\drivers\etc\hosts
}

# -------------------------------------------------------------------------------------------------------------------
# --------------------------------------------- File Explorer navigation  -------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

function Go-Home {
    Set-Location $HOME
}

function Go-Repos {
    Set-Location $HOME/repos
}

function Go-Downloads {
    Set-Location $HOME/Downloads
}

# navigate to the profile directory (resolves through the $PROFILE symlink)
function Go-Profile {
    Set-Location (Split-Path $PROFILE)
}

# -------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------ Virtual environments ---------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

function Uninstall-AllPipPackages {
    $packages = & pip list --format=freeze | ForEach-Object { $_.Split('==')[0] }

    if ($packages.Count -eq 0) {
        Write-Output "No packages found."
        return
    }

    Write-Output "Uninstalling $($packages.Count) package(s)."

    foreach ($package in $packages) {
        & pip uninstall -y $package | Out-Null
        Write-Output "Uninstalled package: $package"
    }

    Write-Output "All packages uninstalled."
}

function Requirements-To-Poetry {
    param (
        [string]$requirementsFilePath = "requirements.txt"
    )

    if (-Not (Test-Path $requirementsFilePath)) {
        Write-Error "Requirements file not found: $requirementsFilePath"
        return
    }

    $requirements = Get-Content $requirementsFilePath

    foreach ($requirement in $requirements) {
        poetry add $requirement
    }
}

# -------------------------------------------------------------------------------------------------------------------
# --------------------------------------------------- Miscellaneous -------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

# create an empty text file
function mkfile {
    param(
        [string]$Path
    )
    New-Item -ItemType File -Path $Path
}

# -------------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------- git stuff ---------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

function Undo-LastCommit {
    git reset --soft HEAD^
}

# -------------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------- WSL ------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

function Restart-WSL {
    wsl --shutdown
    wsl.exe
}

