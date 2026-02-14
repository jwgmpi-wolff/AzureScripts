# Variables
$vmFilterName = "mov*" #"<Filter name of VMs to be restored. Use wildcards to enhance filtering>"
$RecoveryVaultName = "RG-TEST"  #"<Recovery Vault Name>"
$RecoveryVaultResourceGroupName = "VNETMOVE" #"<Resource Group name of Recovery Vault>"
$RecoveryVaultVMPolicyname = "DefaultPolicy" #"<Name of VM Backup Policy>"

# Get the list of VMs
$vms = Get-AzVM


# Set Azure Resource Vault and backup policy that will contain the backups
Get-AzRecoveryServicesVault -ResourceGroupName $RecoveryVaultResourceGroupName -Name $RecoveryVaultName | Set-AzRecoveryServicesVaultContext
$policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "DefaultPolicy"

# Filter the VMs based on the filter name
$filteredVMs = $vms | Where-Object { $_.Name -like $vmFilterName }

# Loop through all VM's that match the name filter
foreach ($vm in $filteredVMs) {

    # Add VM to backup policy
    write-output "Adding VM $($vm.Name) to the Backup Policy"
    Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Policy $policy

    # Run a backup after VM is added to policy - OPTIONAL
    #write-output "Running first backup for VM $($vm.Name)"
    #$vmname = $vm.Name
    #$vmname = $vmname.ToLower()
    #write-output "This will take some time depending on the disk sizes of the VM"
    # $backupcontainer = Get-AzRecoveryServicesBackupContainer -ContainerType "AzureVM" -FriendlyName $vm.Name
    # $item = Get-AzRecoveryServicesBackupItem -Container $backupcontainer -WorkloadType "AzureVM"
    # Backup-AzRecoveryServicesBackupItem -Item $item

}
