 <#
.SYNOPSIS  
 Wrapper script for automation_get_azure_storage_Container_sizes
.DESCRIPTION  
 Wrapper script for automation_get_azure_storage_Container_sizesto html report
.EXAMPLE  
.\disable_public_access_to_storage.ps1.ps1
Version History  
v1.0   - Initial Release  
 

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


Description: 
Connect to Azure: The script initiates a connection to Azure using managed 
identity with the command Connect-AzAccount -Identity.

Fetch Subscriptions: It retrieves a list of all Azure subscriptions available
 to the account using Get-AzSubscription.

Loop Through Subscriptions: For each subscription, it sets the context to the 
 current subscription using Set-AzContext.

Retrieve Storage Accounts: It gathers all storage accounts within the current
 subscription using Get-AzStorageAccount.

Process Each Storage Account:

Disable Public Access: For each storage account, it disables blob public access 
by setting AllowBlobPublicAccess to false using Set-AzStorageAccount.
Create Storage Context: It creates a new storage context using the storage
 account name and key.
Retrieve and Confirm Settings: It retrieves the storage account information
 to confirm the public access setting.
Output Status: It outputs the status of blob public access for each storage 
account, indicating whether public access is disabled.
This script ensures that blob public access is disabled for all storage accounts 
across all subscriptions, enhancing security by preventing unauthorized acces

#> 
 
 
 
 connect-azaccount   -Identity


$AZStorageACCOUNTlist = ''


$subs = Get-AzSubscription  



   foreach ($sub in $subs) 
   {
        Set-AzContext -Subscription $($sub.name)  
        $subscriptioname = $($sub.name)  
        $subscriptionid = $($sub.id)
        

                $StorageAccounts = Get-AzStorageAccount 
 
 
     foreach($storageaccount in   $StorageAccounts )
                            { 

                         ## un block storage 
                        # Disable Allow Storage Account Key Access
                        $scope = "/subscriptions/$($sub.id)/resourceGroups/$($storageaccount.resourcegroupname)/providers/Microsoft.Storage/storageAccounts/$($storageaccount.storageaccountname)"
 

                        Set-AzStorageAccount -ResourceGroupName $($storageaccount.resourcegroupname)-Name $($storageaccount.storageaccountname) -AllowBlobPublicAccess $false   -AllowSharedKeyAccess $true  -force

                         $destContext = New-AzStorageContext -StorageAccountName "$($storageaccount.storageaccountname)" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$($storageaccount.resourcegroupname)" -Name $($storageaccount.storageaccountname)).Value | select -first 1)

                         $storageaccountinfo = get-azstorageaccount -resourcegroupname $($storageaccount.resourcegroupname) -name $($storageaccount.storageaccountname) 
 
                 write-host "Blob Public access is set to $($storageaccountinfo.AllowBlobPublicAccess) " -foregroundcolor darkblue -backgroundcolor white
                }

}


