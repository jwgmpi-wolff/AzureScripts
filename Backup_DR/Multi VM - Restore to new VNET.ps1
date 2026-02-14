# Variables
$vmFilterName = "mov*" #"<Filter name of VMs to be restored. Use wildcards to enhance filtering>"
$RecoveryVaultName = "RG-TEST"  #"<Recovery Vault Name>"
$RecoveryVaultResourceGroupName = "VNETMOVE" #"<Resource Group name of Recovery Vault>"
$targetVMResourceGroupName = "RESTORE" #"<Name of Resource Group where to Restore the VM"
$targetVNetName = "VNET-NEW" #"<Name of VNET to restore VM into>"
$targetSubnetName = "default" #"<Name of SUBNET to restore VM into>"
$targetVNetResourceGroupname = "VNETMOVE" #"<Name of Resource Group VNET>"
$RestoreStagingStorageAccountname = "wrrestorestaging" #"<Name of Restore Staging Storage Account>"
$RestoreStoragrAccountResourceGroupname = "RESTORE" #"<Name of Resource Group Storage Account>"

# Get the list of VMs
$vms = Get-AzVM

# Configure Azure Resource Vault that contains the backups
$vault = Get-AzRecoveryServicesVault -ResourceGroupName $RecoveryVaultResourceGroupName -Name $RecoveryVaultName

# Filter the VMs based on the filter name
$filteredVMs = $vms | Where-Object { $_.Name -like $vmFilterName }

# Loop through all VM's that match the name filter
foreach ($vm in $filteredVMs) {

    # Shutdown the original VM
    Write-Output "Turning off VM $($vm.Name)..."
    Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
     
    # Wait for any restore Jobs to finish
    $Jobs = Get-AzRecoveryServicesBackupJob -Status InProgress -VaultId $vault.ID
    try {Get-AzRecoveryServicesBackupJobDetail -Job $Jobs[0] -VaultId $vault.ID -Timeout 30}
    Catch {write-Output "No active restore jobs running"}

    # Start restore of VM that matches the name filter
    Write-Output "Restoring VM $($vm.Name) into new VNET"
    $vmname = $vm.Name
    $vmname = $vmname.ToLower()
    $BackupItem = Get-AzRecoveryServicesBackupItem -BackupManagementType "AzureVM" -WorkloadType "AzureVM" -Name $vmname -VaultId $vault.ID
    $BackupItem = $backupItem | Where-Object {$_.Name.EndsWith(";$($vmname)")}
    $StartDate = (Get-Date).AddDays(-7)
    $EndDate = Get-Date
    $RP = Get-AzRecoveryServicesBackupRecoveryPoint -Item $BackupItem -StartDate $StartDate.ToUniversalTime() -EndDate $EndDate.ToUniversalTime() -VaultId $vault.ID
    Restore-AzRecoveryServicesBackupItem -RecoveryPoint $RP[0] -TargetResourceGroupName $targetVMResourceGroupName -StorageAccountName $RestoreStagingStorageAccountname -StorageAccountResourceGroupName $RestoreStoragrAccountResourceGroupname -TargetVMName $vm.Name -TargetVNetName $targetVNetName -TargetVNetResourceGroup $targetVNetResourceGroupname -TargetSubnetName $targetSubnetName -VaultId $vault.ID -VaultLocation $vault.Location

}
