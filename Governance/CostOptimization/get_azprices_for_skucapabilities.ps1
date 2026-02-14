connect-azaccount  -identity #-Environment AzureUSGovernment



# Login to Azure - if already logged in, use existing credentials.
Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
 

 
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken

 


$subscriptioncosts = ''


$Uri = "https://prices.azure.com/api/retail/prices?api-version=2021-10-01-preview"

 
 

while ($Uri) {
 

    $Response = Invoke-RestMethod -Method Get -Uri $Uri  



    foreach ($Item in $Response.Items) {
        $Meter = $Item.meterName

        $responseobj = new-object PSObject 

        
        $responseobj | Add-Member -MemberType NoteProperty -Name armRegionName -value $($item.armRegionName)
        $responseobj | Add-Member -MemberType NoteProperty -Name armSkuName -value $($item.armSkuName)
        $responseobj | Add-Member -MemberType NoteProperty -Name availabilityId -value $($item.availabilityId)
        $responseobj | Add-Member -MemberType NoteProperty -Name currencyCode -value $($item.currencyCode)
        $responseobj | Add-Member -MemberType NoteProperty -Name effectiveStartDate -value $($item.effectiveStartDate)
        $responseobj | Add-Member -MemberType NoteProperty -Name isPrimaryMeterRegion -value $($item.isPrimaryMeterRegion)
        $responseobj | Add-Member -MemberType NoteProperty -Name location -value $($item.location)
        $responseobj | Add-Member -MemberType NoteProperty -Name meterId -value $($item.meterId)
        $responseobj | Add-Member -MemberType NoteProperty -Name meterName -value $($item.meterName)
        $responseobj | Add-Member -MemberType NoteProperty -Name productId -value $($item.productId)
        $responseobj | Add-Member -MemberType NoteProperty -Name productName -value $($item.productName)
        $responseobj | Add-Member -MemberType NoteProperty -Name retailPrice -value $($item.retailPrice)
        $responseobj | Add-Member -MemberType NoteProperty -Name serviceFamily -value $($item.serviceFamily)
        $responseobj | Add-Member -MemberType NoteProperty -Name serviceId -value $($item.serviceId)
        $responseobj | Add-Member -MemberType NoteProperty -Name serviceName -value $($item.serviceName)
        $responseobj | Add-Member -MemberType NoteProperty -Name skuId -value $($item.skuId)
        $responseobj | Add-Member -MemberType NoteProperty -Name skuName -value $($item.skuName)
        $responseobj | Add-Member -MemberType NoteProperty -Name tierMinimumUnits -value $($item.tierMinimumUnits)
        $responseobj | Add-Member -MemberType NoteProperty -Name type -value $($item.type)
        $responseobj | Add-Member -MemberType NoteProperty -Name unitOfMeasure -value $($item.unitOfMeasure)
        $responseobj | Add-Member -MemberType NoteProperty -Name unitPrice -value $($item.unitPrice)
 


        [array]$subscriptioncosts += $responseobj
         
    }

    $Uri = $Response.NextPageLink
}


 


 $resultsfilename = "azureprices.csv"

  $subscriptioncosts | select armRegionName, `
armSkuName           , `
availabilityId       , `
currencyCode         , `
effectiveStartDate   , `
isPrimaryMeterRegion , `
location             , `
meterId              , `
meterName            , `
productId            , `
productName          , `
retailPrice          , `
serviceFamily        , `
serviceId            , `
serviceName          , `
skuId                , `
skuName              , `
tierMinimumUnits     , `
type                 , `
unitOfMeasure        , `
unitPrice        | export-csv $resultsfilename -NoTypeInformation


 ##### storage subinfo

$Region = "eastus"
#####  Subscription name if results storage accounts are in a separate subscription

### If results storage account is in a separate tenant 
#Connect-azaccount   # for storage account tenant and subscription context verification

 $subscriptionselected = 'wolffentpsub'


$resourcegroupname = 'jwgovernance'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'skucapabilities'
 
 $storagecontainer = 'azureprices'



### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

 

#BEGIN Create Storage Accounts
 
 
 
    ################  Set up storage account and containers ################
      
 

        ### end storagesub info

        Set-azcontext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

         ####resourcegroup 
         try
         {
             if (!(Get-azresourcegroup -Location "$storageregion" -Name $resourcegroupname -erroraction "silentlycontinue" ) )
            {  
                Write-Host "resourcegroup Does Not Exist, Creating resourcegroup  : $resourcegroupname Now"

                # b. Provision resourcegroup
                New-azresourcegroup  -Name  $resourcegroupname -Location $storageregion -Tag @{"owner" = "Ownername"; "purpose" = "Az Automation" } -Verbose -Force
 
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
                New-AzStorageAccount  -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $storageregion -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Ownername"; "purpose" = "Az Automation storage write" } -Verbose 
 
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


          Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -force



################################################
 












