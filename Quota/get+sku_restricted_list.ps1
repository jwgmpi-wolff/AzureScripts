# Connect to your Azure account
Connect-AzAccount -identity

# Specify the region you want to check (e.g., eastus)
#$region = "eastus"
$skurestrictions = ''
$subscriptions = get-azsubscription  | ogv -title " Select a Subscriptions to check : " -PassThru | select name, id

 $Regions = get-azlocation  | ogv -title " Select a region to check : " -PassThru | select location

foreach($sub in $subscriptions)
{
    set-azcontext -Subscription $($sub.name) 



        foreach($Region in $Regions)
        {
            # Get available SKUs for virtual machines in the specified region
            $vmSkus = Get-AzComputeResourceSku -Location $($region.location)   
 
    
            foreach($Skufamily in $vmskus)
            {
                if($($skufamily.Restrictions.reasoncode) -like '*NotAvailableForSubscription*')
                {

                $reasoncode =  'Not Available For Subscription'
                }
                else
                {
                 $reasoncode =   $($skufamily.Restrictions.reasoncode)

                }


                $skufamilyobj = new-object PSObject
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Name -value $($skufamily.name)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Family -value $($skufamily.Family)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name ResourceType -value $($skufamily.ResourceType)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Location -value $($skufamily.Locations)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Tier -value $($skufamily.Tier)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name ReasonCode -value "$reasoncode"
                $skufamilyobj | Add-Member -MemberType NoteProperty -name Subscription -value $($sub.name)
                $skufamilyobj | Add-Member -MemberType NoteProperty -name "RestrictionInfo" -value "$($skufamily.RestrictionInfo)" 
 

                [array]$skurestrictions += $skufamilyobj
            }
        }

}

$skurestrictions





$CSS = @"

<Title>Azure sku family restirctions : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure sku family restirctions : $(Get-Date -Format 'dd MMMM yyyy')  </H2>

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




($skurestrictions | select name ,Family,ResourceType,Tier, ReasonCode, Subscription, RestrictionInfo  ,Location `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\restrictedSkus.html"


invoke-item "c:\temp\restrictedSkus.html"





#######################################################################

$Region = "West US"

 $subscriptionselected = 'wolffentpsub'





 $resultsfilename = 'restrictedskus.csv'


$skurestrictions | select name ,Family,ResourceType,Tier, ReasonCode, Subscription, RestrictionInfo  ,Location  `
 | export-csv $resultsfilename 




$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'
$storagecontainer = 'restrictedskus'
### end storagesub info

$azaccount = set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)


#BEGIN Create Storage Accounts
 
 
######################## Storage account info for source files and history files


## un block storage 
# Enable Allow Storage Account Key Access
$scope = "/subscriptions/$($subscriptioninfo.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Storage/storageAccounts/$storageaccountname"


Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowBlobPublicAccess $true -AllowSharedKeyAccess $true  -force

 $destContext = New-AzStorageContext -StorageAccountName "$storageaccountname" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$resourcegroupname" -Name $storageaccountname).Value | select -first 1)

 ###################################
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose
 
     
        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
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
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -force
        
 
 
 









