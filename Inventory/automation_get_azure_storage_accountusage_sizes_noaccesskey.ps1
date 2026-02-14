 <#
.SYNOPSIS  
 Wrapper script for automation_get_azure_storage_Container_sizes
.DESCRIPTION  
 Wrapper script for automation_get_azure_storage_Container_sizesto html report
.EXAMPLE  
.\automation_get_azure_storage_Container_sizes.ps1
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

#> 

### uncomment when using for AAzure Automation
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
  
                    #### Block Public access
                      Set-AzStorageAccount -ResourceGroupName $($storageaccount.resourcegroupname)-Name $($storageaccount.storageaccountname) -AllowBlobPublicAccess $false -force
               
                     ## un block storage 
                    # Enable Allow Storage Account Key Access
                    $scope = "/subscriptions/$($sub.id)/resourceGroups/$($storageaccount.resourcegroupname)/providers/Microsoft.Storage/storageAccounts/$($storageaccount.storageaccountname)"
                      
                   Set-AzStorageAccount -ResourceGroupName $($storageaccount.resourcegroupname)-Name $($storageaccount.storageaccountname)   -AllowSharedKeyAccess $true  -force

                     $destContext = New-AzStorageContext -StorageAccountName "$($storageaccount.storageaccountname)" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$($storageaccount.resourcegroupname)" -Name $($storageaccount.storageaccountname)).Value | select -first 1)

                     $storageaccountinfo = get-azstorageaccount -resourcegroupname $($storageaccount.resourcegroupname) -name $($storageaccount.storageaccountname)  
 


                         
                        $CurrentSAID = $($storageaccount.id)

                      #  [decimal]$usedCapacity = (Get-AzMetric -ResourceId $CurrentSAID -MetricName "UsedCapacity").Data  
                    #    [decimal]$usedCapacityInMB = $usedCapacity.average / 1024 / 1024  

                                  # Retrieve the metric data
                            $metricData = (Get-AzMetric -ResourceId $CurrentSAID -MetricName "UsedCapacity").Data

                            # Assuming you want the average value from the metric data
                            $averageValue = $metricData | Select-Object -ExpandProperty Average

                            # Convert the average value to a decimal
                            [decimal]$usedCapacity = [decimal]$averageValue / 1024 / 1024  / 1024
                             [decimal]$usedCapacityInMB = [decimal]$averageValue / 1024 / 1024   

                                     $Resource = Get-AzResource -Name $($StorageAccount.StorageAccountName) | select -Property *
                                     $obj = new-object PSOBJECT

                                           $Resource.Tags.GetEnumerator() | ForEach-Object {

                                               #Write-Output "$($_.key)   = $($_.Value)"
                                        
 
                                              $obj | add-member -membertype Noteproperty -name $($_.key) -value $($_.value)

                                              }

                              #Convert length to GB

                                    [decimal]$TotalSIZEGB = $usedCapacity 

                       write-host "$($StorageAccount.storageaccountname) = $TotalSIZEGB" -ForegroundColor CYAN

                                        $obj | add-member -membertype NoteProperty -name "subscriptioname" -value "$subscriptioname"
                                        $obj | add-member -membertype NoteProperty -name "Resourcegroup" -value "$($storageaccount.resourcegroupname)"
                                        $obj | add-member -membertype NoteProperty -name "storageaccountname" -value "$($storageaccount.storageaccountname)"
                                        $obj | add-member -membertype NoteProperty -name "SkuName" -value $($storageaccountinfo.sku.Name)
                                        $obj | add-member -membertype NoteProperty -name "Kind" -value $($storageaccountinfo.Kind)
                                        $obj | add-member -membertype NoteProperty -name "AccessTier"  -value  $($storageaccountinfo.AccessTier)
                                        $obj | add-member -membertype NoteProperty -name  "LargeFileShares" -value $($storageaccountinfo.LargeFileSharesState)
                                        $obj | add-member -membertype NoteProperty -name "TOTALSIZEMB" -Value $($usedCapacityInMB) 
                                        $obj | add-member -membertype NoteProperty -name "TotalSIZEGB" -Value $($TotalSIZEGB) 

                                   [array]$AZStorageACCOUNTlist +=     $obj  

                      
                        }  
                }  
      
 

  $date = $(Get-Date -Format 'dd MMMM yyyy' )
 
    $CSS = @"
<Title> Azure Storage container sizes Report: $date </Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	border-top: 1px solid #C1DAD7;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #6D929B;
}
</Style>
"@


 

 
$AZStoragelist_report = ($AZStorageACCOUNTlist | sort-object subscriptioname   | Select  * |`   
ConvertTo-Html -Head $CSS )  | out-file "c:\temp\Azure_storage_account_sizes.html" 

invoke-item "c:\temp\Azure_storage_account_sizes.html" 
 

 
 
 ######### Uncomment and configure to send results to storage account blob 


 
 $date = $(Get-Date -Format 'dd MMMM yyyy' )
 
########### Prepare for storage account export

$csvresults = $AZStorageACCOUNTlist | sort-object subscriptioname   |   Select  *

 $resultsfilename = "storageaccountusage.csv"

$csvresults  | export-csv $resultsfilename  -NoTypeInformation   

# end vmss data 


##### storage subinfo

$Region = "westus"
 $date = Get-Date -Format MMddyyyy
 $subscriptionselected = 'wolffentpsub'



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | select tenantid
$storageaccountname = 'wolffautosa'
$storagecontainer = 'storageaccountusage'
### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $($storageaccountname) ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account:$($storageaccountname) Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $($storageaccountname) -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose
 
     
        Get-AzStorageAccount -Name   $($storageaccountname)  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of$($storageaccount.name)"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $($storageaccountname)).value | select -first 1
        $destContext = New-azStorageContext  –StorageAccountName $($storageaccountname) `
                                        -StorageAccountKey $StorageKey


             #Upload user.csv to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext
                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfile  -File $resultsfilename -Context $destContext -FORCE
        
        
 
 
 





