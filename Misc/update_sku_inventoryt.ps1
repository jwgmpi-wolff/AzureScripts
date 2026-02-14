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

    Script Name: update_allowed_sku_master_list.ps1
    Description : 
    This Azure PowerShell script performs several tasks related to managing SKUs and storage accounts in an Azure 
    Government tenant. Here’s a summary with moderate detail:

Initial Setup:
 
Imports necessary modules (Az.Storage and Az.Resources).
Subscription and Resource Group Configuration:
Selects a subscription and resource group.
Retrieves subscription information and tenant ID.
Defines storage account and container names, and sets the region for the storage account.
Collecting Allowed SKUs and Regions:
Sets the Azure context to the selected subscription and tenant.
Prompts the user to select regions using Out-GridView.
For each selected region, retrieves available SKUs for virtual machines and their details (e.g., name, max data disk count, memory, number of cores, OS disk size, resource disk size, region, and region restrictions).
Setting Up Storage Account and Containers:
Checks if the specified resource group exists; if not, creates it.
Checks if the specified storage account exists; if not, creates it.
Retrieves the storage account key and creates a storage context.
Checks if the specified containers (skuinventoryupdates, skuinventoryhistory, skudata) exist; if not, creates them.
Updating SKU List:
Retrieves the current SKU list from the storage container.
Updates the SKU list with new data.
Writes the updated SKU list back to the storage container.
This script ensures that the necessary resources and configurations are in place for managing SKU inventories in an Azure Government environment
 
 #>



 
######  for Azure government tenant use  , run connect-azconnect -Environment AzureUSGovernment
cls
 


connect-azaccount -identity

import-module az.storage
import-module Az.Resources 

 
$subscriptionselected = 'wolffentpsub'
$resourcegroupname = 'jwgovernance'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'skuinventorysa'
$storagecontainer = 'skuinventoryupdates'
$historycontainer = 'skuinventoryhistory'
$sourcecontainer = 'skudata'
$region = 'eastus' ## region used for the storage account location only
 
 


################  Collect allowed sku list and region ################

 $date = get-date -format "DDmmyyyy"

# Set Azure context
Set-AzContext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

# Get SKUs to allowskus
# Get SKUs to allowskus
$skuregions = get-azlocation | Out-GridView -Title "Select Regions skus:" -PassThru | Select displayname ,location
 $skuregions

 foreach($skuregion in $skuregions)
 {
        $regionsskulist = ''   
        # Get available SKUs for virtual machines in the specified region
            $skulist = Get-AzComputeResourceSku -Location "$($skuregion.location)"  | where-object {$_.resourcetype -like '*virtualmachine*'}
 
    
        FOREACH($sku in $skulist)
        {

        

            foreach($Skufamily in $sku)
            {
                if($($skufamily.Restrictions.reasoncode) -like '*NotAvailableForSubscription*')
                {

                $reasoncode =  'Not Available For Subscription'
                }
                else
                {
                 $reasoncode =   $($skufamily.Restrictions.reasoncode)

                }
             }
           
            

            $SKUSIZES  = get-azvmsize -Location "$($skuregion.location)"  | where-object {$_.name -eq "$($sku.name)" }
           # $skuregion

            $SKUOBJ = NEW-OBJECT psobject

            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name name -value $($SKUSIZES.name)
            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name MaxDataDiskCount -value $($SKUSIZES.MaxDataDiskCount)
            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name MemoryInMB -value $($SKUSIZES.MemoryInMB)
            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name NumberOfCores -value $($SKUSIZES.NumberOfCores)
            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name OSDiskSizeInMB -value $($SKUSIZES.OSDiskSizeInMB)
            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name ResourceDiskSizeInMB -value $($SKUSIZES.ResourceDiskSizeInMB)
            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name Region -value "$($skuregion.location)"
            $SKUOBJ | ADD-Member -MemberType NoteProperty -Name RegionRestriction -value "$($skufamily.RestrictionInfo)" 

            [array]$regionsskulist += $SKUOBJ
            

         }
        ################  Set up storage account and containers ################
            $regionsskulist 
 

        ### end storagesub info

        Set-azcontext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

         ####resourcegroup 
         try
         {
             if (!(Get-azresourcegroup -Location "$region" -Name $resourcegroupname -erroraction "silentlycontinue" ) )
            {  
                Write-Host "resourcegroup Does Not Exist, Creating resourcegroup  : $resourcegroupname Now"

                # b. Provision resourcegroup
                New-azresourcegroup  -Name  $resourcegroupname -Location $region -Tag @{"owner" = "Ownername"; "purpose" = "Az Automation" } -Verbose -Force
 
               start-sleep 30
                Get-azresourcegroup    -ResourceGroupName  $resourcegroupname  -verbose
             }
           }
           Catch
           {
                 WRITE-DEBUG "Resourcegroup   Aleady Exists, SKipping Creation of resourcegroupname"
   
           }

        ############ Storage Account
    
         try
         {
             if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname  -erroraction "silentlycontinue" ) )
            {  
                Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

                # b. Provision storage account
                New-AzStorageAccount  -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Ownername"; "purpose" = "Az Automation storage write" } -Verbose 
 
                start-sleep 30

                Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
             }
           }
           Catch
           {
                 WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
           } 
 
                     #Upload user.json to storage account


          $date = get-date -Format 'yyyyMMddHHmmss'   


        set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)



        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
                         -StorageAccountKey $StorageKey
        if($destContext  )
        {

        ##########  Containers  
                try
                    {
                          if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext -erroraction silentlycontinue))
                             { 
                                 New-azStorageContainer $storagecontainer -Context $destContext

                         
                                start-sleep 30

                                }
                     }
                catch
                     {
                        Write-Warning " $storagecontainer container already exists" 
                     }


                 try
                    {
                          if (!(get-azstoragecontainer -Name $historycontainer -Context $destContext -erroraction silentlycontinue))
                             { 
                                 New-azStorageContainer $historycontainer -Context $destContext

                         
                                start-sleep 30

                                }
                     }
                catch
                     {
                        Write-Warning " $historycontainer container already exists" 
                     }

                 try
                    {
                          if (!(get-azstoragecontainer -Name $sourcecontainer -Context $destContext -erroraction silentlycontinue))
                             { 
                                 New-azStorageContainer $sourcecontainer -Context $destContext

                         
                                start-sleep 30

                                }
                     }
                catch
                     {
                        Write-Warning " $sourcecontainer container already exists" 
                     }

        }
        else
        {

            Write-Warning " $($destContext.StorageAccountName) connection not made" -ErrorAction stop


        }




            $currentSkulistname = "sku_list_$($skuregion.location).csv"


            if (Get-AzStorageBlob -Blob "$currentSkulistname" -Container $storagecontainer -Context $destContext -ErrorAction SilentlyContinue) {
               
                $currentallowedlistcontent = Get-AzStorageBlobContent -Blob $currentSkulistname -Container $storagecontainer -Context $destContext -Destination "$env:SystemRoot\System32\$currentSkulistname" -Force

                # Rename the file with the current date
                $date = Get-Date -Format 'yyyyMMddHHmmss'
                $historydatename = "sku_list_$($skuregion.location)_$date.csv"
                $historyfilepath = "$env:SystemRoot\System32\$historydatename"
                Rename-Item -Path "$env:SystemRoot\System32\$currentSkulistname" -NewName $historyfilepath

                            # Create a new storage context for the destination container
                $historycontext = New-AzStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $StorageKey

                # Upload the renamed content to the destination container
                Set-AzStorageBlobContent -Container $historycontainer -Blob $historydatename -File "$env:SystemRoot\System32\$historydatename" -Context $historycontext -Force
           
            } else {
                Write-Warning "$currentSkulistname list does not exist in $($destContext.BlobEndPoint)" -ErrorAction Stop
            }


 

        #######################  Update with new list of allowed SKUS 

 
        $sku_listname = "sku_list_$($skuregion.location).csv"

        $regionsskulist | select name,MaxDataDiskCount,MemoryInMB,NumberOfCores,OSDiskSizeInMB,Region, regionrestriction  | export-csv $sku_listname -NoTypeInformation


                ##################  Write updated parameters file to Storage account 

               Set-azStorageBlobContent -Container $storagecontainer -Blob "$sku_listname"  -File "$sku_listname"  -Context $destContext -Force


}

























