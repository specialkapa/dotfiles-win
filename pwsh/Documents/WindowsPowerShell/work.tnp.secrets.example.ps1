# TNP Bastion identifiers — copy this file to work.tnp.secrets.ps1 (gitignored,
# next to the profile) and fill in the real values. work.tnp.ps1 dot-sources it.
$env:TNP_BASTION_NAME       = "bas-xxx"
$env:TNP_RESOURCE_GROUP     = "rg-xxx"
$env:TNP_TARGET_RESOURCE_ID = "/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/<vm-name>"
$env:TNP_BASTION_USER       = "youradminuser"
