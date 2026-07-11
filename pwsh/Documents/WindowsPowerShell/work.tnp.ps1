# =====================================================================
#  TNP (True North Partners) work-specific helpers and aliases.
#
#  Loaded by the profile ONLY if this file is present, so a personal
#  machine that doesn't have it stays free of company-specific config.
#
#  Contains NO internal identifiers — the Azure subscription / resource
#  IDs live in the gitignored work.tnp.secrets.ps1 (copy it from
#  work.tnp.secrets.example.ps1). This file is therefore safe to commit.
# =====================================================================

# load local, gitignored secrets (Azure resource identifiers) if present
$tnpSecrets = Join-Path $PSScriptRoot 'work.tnp.secrets.ps1'
if (Test-Path $tnpSecrets) { . $tnpSecrets }

# -------------------------------------------------------------------------------------------------------------------
# ---------------------------------------------------- Azure CLI ----------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

function Invoke-BastionCommand {
    <#
    .SYNOPSIS
    Executes Azure Bastion SSH / RDP / tunnel commands against the Atlas prod VM.

    .PARAMETER Type
    One of 'ssh', 'rdp', or 'tunnel'.

    .EXAMPLE
    Invoke-BastionCommand -Type ssh
    #>

    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("ssh", "rdp", "tunnel")]
        [string]$Type
    )

    $name             = $env:TNP_BASTION_NAME
    $resourceGroup    = $env:TNP_RESOURCE_GROUP
    $targetResourceId = $env:TNP_TARGET_RESOURCE_ID
    $username         = $env:TNP_BASTION_USER
    $authType         = "password"

    if (-not ($name -and $resourceGroup -and $targetResourceId -and $username)) {
        Write-Host "TNP Bastion config not set. Copy work.tnp.secrets.example.ps1 to " -NoNewline
        Write-Host "work.tnp.secrets.ps1 (next to the profile) and fill it in."
        return
    }

    if ($Type -eq "ssh") {
        $sshCommand = "az network bastion ssh --name `"$name`" --resource-group `"$resourceGroup`" --target-resource-id `"$targetResourceId`" --auth-type `"$authType`" --username $username"
        Invoke-Expression $sshCommand
    } elseif ($Type -eq "rdp") {
        $rdpCommand = "az network bastion rdp --name `"$name`" --resource-group `"$resourceGroup`" --target-resource-id `"$targetResourceId`" --auth-type `"$authType`""
        Invoke-Expression $rdpCommand
    } elseif ($Type -eq "tunnel") {
        $tunnelCommand = az network bastion tunnel --name $name --resource-group $resourceGroup --target-resource-id $targetResourceId --resource-port 22 --port 2022
        Invoke-Expression $tunnelCommand
    }
}

# -------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------- TNP aliases -----------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------

Set-Alias az-ghb       Invoke-BastionCommand
