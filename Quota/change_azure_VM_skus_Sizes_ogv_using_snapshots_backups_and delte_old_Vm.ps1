

<# 

.NOTES

    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 

    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 

    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 

    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all

    implied warranties including, without limitation, any implied warranties of merchantability

    or of fitness for a particular purpose. The entire risk arising out of the use or performance

    of the sample and documentation remains with you. In no event shall Microsoft, its authors,

    or anyone else involved in the creation, production, or delivery of the script be liable for 

    any damages whatsoever (including, without limitation, damages for loss of business profits, 

    business interruption, loss of business information, or other pecuniary loss) arising out of 

    the use of or inability to use the sample or documentation, even if Microsoft has been advised 

    of the possibility of such damages, rising out of the use of or inability to use the sample script, 

    even if Microsoft has been advised of the possibility of such damages.


 $DirectoryToCreate = 'C:\temp'

 if (-not (Test-Path -LiteralPath $DirectoryToCreate)) {
    
    try {
        New-Item -Path $DirectoryToCreate -ItemType Directory -ErrorAction Stop | Out-Null #-Force
    }
    catch {
        Write-Error -Message "Unable to create directory '$DirectoryToCreate'. Error was: $_" -ErrorAction Stop
    }
    "Successfully created directory '$DirectoryToCreate'."

}
else {
    "Directory already existed"
}
#> 
 
 ######################33
 ##  Necessary Modules to be imported.

import-module Az.Compute -force 
import-module az.marketplaceordering  -force
import-module Az.BareMetal -force 
import-module -name az.RecoveryServices | out-null

 ############
 ## connect to Azure with authorized credentials 
 
 Connect-AzAccount -identity # -Environment AzureUSGovernment

 


function get_subscriptions
{
          

				  
            $sub  = get-azsubscription | ogv -passthru | select subscriptionname, subscriptionID
            

             
                    $global:EnvironmentSubscriptionName = $sub.subscriptionname
                    $global:EnvironmentSubscriptionid =  $sub.subscriptionID

                        Select-azSubscription   -SubscriptionName $EnvironmentSubscriptionName -verbose
              #   set-azuresubscription -SubscriptionName $EnvironmentSubscriptionName

					set-azcontext -Subscription $($sub.subscriptionname)


				  Get-azSubscription  -Verbose  
				  
 
 

            # Present locations and allow user to choose location of their choice for Resource creation.
            #
}

#get_subscriptions

### PRep for skus completeness 

Get-AzResourceProvider -ListAvailable | where ProviderNamespace -eq 'microsoft.avs' |  Register-AzResourceProvider | out-null
Get-AzResourceProvider -ListAvailable | where ProviderNamespace -eq 'Microsoft.BareMetalInfrastructure' |  Register-AzResourceProvider | out-null


function get_locations
{
             $location =   Get-azLocation | ogv -PassThru | select displayname, location
  			 $resourceloc = $location.location
			
            Write-Host "Region successfully populated. All Resources will be created in the region: " $resourceloc -ForegroundColor Green
            return $resourceloc 
}
#

#$resourceloc = get_locations



  function get_skus([string] $resourceloc)
  {
		  #View the templates available
        
        $location= $($loc.Location)

 
        $vmSizes  =  Get-azVMSize -Location "$resourceloc" | select-object -Property * | ogv -passthru   | select * -first 1
        Return $vmsizes
  }


  Function backup_vm ([psobject]$vm,[psobject]$vaultselected)
  {
        $vmname = $($vm.name) 
  

            $subscriptionselected = $subscriptions | ogv -Title " Select the subscription for the restoration process: " -PassThru | Select * -First 1

            set-azcontext -Subscription $($subscriptionselected.name) 


 

            $recoveryservicesvaults = Get-AzRecoveryServicesVault

            $vaultselected = $recoveryservicesvaults | ogv -Title " Select recovery services vault to use :" -PassThru | select *

            $vault = Get-AzRecoveryServicesVault -ResourceGroupName $($vaultselected.ResourceGroupName) -Name $($vaultselected.Name) 

             $startDate = ((Get-Date).addmonths(-6)).ToUniversalTime()
             $endDate = (Get-Date).ToUniversalTime()


            Set-AzRecoveryServicesVaultContext -Vault $vault 


            $containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.ID

            $containerslist = $containers | ogv -title " Select a container to get backups from:" -PassThru | select *

            $container = Get-AzRecoveryServicesBackupContainer -ContainerType "AzureVM" -FriendlyName "$($containerslist.friendlyname)" -VaultId $($vault.ID)

            $item = Get-AzRecoveryServicesBackupItem -Container  $container -WorkloadType "AzureVM"

  
          # Get VM ID
       $vminfo = Get-AzVM -ResourceGroupName $($VM.resourcegroupname) -Name $($vm.name)
        $vmID = $vminfo.Id

       <# # Create backup policy
        $policy = New-AzBackupPolicy -ResourceGroupName $resourceGroupName -Name $backupPolicyName `
            -ScheduleRunFrequency "Daily" -ScheduleRunTimes "1200" `
            -RetentionDaily 14 -RetentionWeekly 4 -RetentionMonthly 12

       

        # Enable backup
        Enable-AzBackupProtection -ResourceGroupName $resourceGroupName -Name $vmName `
            -Policy $policy -BackupVaultName $backupVaultName
        #>


        # Trigger backup
        $backitup = Backup-AzRecoveryServicesBackupItem -Item $item -BackupType CopyOnlyFull

 
        #Restore:

        # Variables for restore
        $resourceGroupName = "$($vm.resourcegroupname)"
        $vmName = "$vmname"
        $backupVaultName = "$($vaultselected.name)"


  
      
    return  $vminfo  
  }


 
 
 $vmstoupdate = get-azvm | ogv -title " Select the VMs for sku changes: " -PassThru | Select * 




 foreach($vm in $vmstoupdate)
 {

        $vmbackupstatus =  backup_vm -vm $vm -vaultselected $vaultselected
    
        do {
         # Get the backup status
            $status = Get-AzRecoveryServicesBackupStatus -name $($vminfo.name) -resourcegroupname $($vminfo.ResourceGroupName) -Type AzureVM -Verbose
            Write-Host " Checking for backup to be completed ..." -ForegroundColor Cyan
            # Output the status
            $($status.backup)
            Start-Sleep -Seconds 30

         } until ($status -eq "Completed")

          Write-Host "Backup completed $status..." -ForegroundColor green



           $VMSKUselected =  get_skus( $($vm.location) )  
            $VMSKUselected
 
        # Define parameters
        $resourceGroupName = "$($vm.ResourceGroupName)"
        $vmName = "$($vm.Name)"
        $newVmSize = "$($VMSKUselected.name)"



##########################

        # Get the NIC and Subnet of the current VM
        $currentNICId = $vm.NetworkProfile.NetworkInterfaces[0].Id
        $currentNIC = Get-AzNetworkInterface -ResourceGroupName $resourceGroup -Name (Split-Path -Leaf $currentNICId)
        $subnetId = $currentNIC.IpConfigurations[0].Subnet.Id

        # Set the new VM Name
        $vmNameNew = "$vmname-v5"


        # Move Pagefile to OS Disk inside the VM
        $script = "wmic computersystem set AutomaticManagedPagefile=False"
        Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString $script

        # Stop VM and set a ReadOnly Lock
        Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force
            Set-AzResourceLock -LockLevel ReadOnly `
            -LockNotes "VM moved to new SKu without Temp Disk" `
            -LockName "ResizeLock" `
            -ResourceGroupName $resourceGroup `
            -ResourceName $vmName `
            -ResourceType "Microsoft.Compute/virtualMachines" `
            -Force

        # Create Snapshot of the OS Disk
        $snapshotName = $vmname+"OSDiskSnapshot"
        $osDisk = Get-AzDisk -ResourceGroupName $resourceGroup -DiskName $vm.StorageProfile.OsDisk.Name
        $snapshotConfig = New-AzSnapshotConfig -Location $location -SourceUri $osDisk.Id -CreateOption Copy
        New-AzSnapshot -Snapshot $snapshotConfig -SnapshotName $snapshotName -ResourceGroupName $resourceGroup

        # Create a new Managed Disk from the Snapshot
        $diskName = $vmNameNew+"-OSDisk"
        $snapshot = Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName 
        $diskConfig = New-AzDiskConfig -Location $location -SourceResourceId $snapshot.id -CreateOption Copy
        New-AzDisk -Disk $diskConfig -DiskName $diskName -ResourceGroupName $resourceGroup

        # Create a new VM and NIC but use the copied disk
        #$vmSize = $currentSku.Replace('v3','v5')
        $vmsize = $newVmSize
        $newNICname = $vmNameNew+"-NIC"
        $newNIC = New-AzNetworkInterface -Name $newNICname -ResourceGroupName $resourceGroup -Location $location -SubnetId $subnetId
        $ManagedDisk= Get-AzDisk -ResourceGroupName $resourceGroup -DiskName $diskName
        $vmConfig = New-AzVMConfig -VMName $vmNameNew -VMSize $vmSize
        $vmConfig = Set-AzVMOSDisk -VM $vmConfig -ManagedDiskId $ManagedDisk.id -CreateOption Attach -Windows
        $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $newNIC.Id
        $vmConfig = Set-AzureRmVMBootDiagnostics -VM $vmConfig -disable
        New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig

        #Start newly created VM
        start-azvm -ResourceGroupName $resourceGroup -Name $vmNameNew



}














