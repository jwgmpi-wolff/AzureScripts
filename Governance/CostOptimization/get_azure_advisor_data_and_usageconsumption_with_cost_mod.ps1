
 Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'

   

 connect-azaccount   -identity   # -Environment AzureUSGovernment # -identity
  


####################  modules

import-module -Name az.billing -force -ErrorAction SilentlyContinue

import-module -Name az.advisor -force -ErrorAction SilentlyContinue
 import-module -name Az.Reservations -force  -ErrorAction SilentlyContinue



 
function Get-ConsumptionUsageDetailSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$StartDate,

        [Parameter(Mandatory=$true)]
        [datetime]$EndDate,

        [Parameter()]
        [int]$Top = 5000
    )

    # Capture context for a useful message
    $ctx  = Get-AzContext
    $sub  = $ctx.Subscription
    $acct = $ctx.Account
    $tenant = $ctx.Tenant

    try {
        # Make errors catchable
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        # Call the API
        $data = Get-AzConsumptionUsageDetail -StartDate $StartDate -EndDate $EndDate -Top $Top

        $ErrorActionPreference = $prev
        return $data
    }
    catch {
        $ErrorActionPreference = $prev

        # Extract as much as we can from the exception without assuming structure
        $ex       = $_.Exception
        $msg      = ($_.Exception.Message + " " + ($_.ErrorDetails.Message | Out-String)).Trim()
        $fqid     = $_.FullyQualifiedErrorId
        $cat      = $_.CategoryInfo.Category
        $status   = $null
        $errorCode = $null

        # Attempt to pull HTTP status / error code if present (varies by Az module/version)
        if ($ex.PSObject.Properties.Name -contains 'Response') {
            try { $status = $ex.Response.StatusCode.value__ } catch {}
        }
        if ($ex.PSObject.Properties.Name -contains 'Body') {
            try {
                $bodyObj = $ex.Body | ConvertFrom-Json -ErrorAction Stop
                $errorCode = $bodyObj.error.code
                if (-not $msg -and $bodyObj.error.message) { $msg = $bodyObj.error.message }
            } catch {}
        }

        $isBillingRestricted =
            ($msg -match 'Billing' -or
             $msg -match 'Cost Management' -or
             $msg -match 'consumption' -or
             $msg -match 'not authorized' -or
             $msg -match 'AuthorizationFailed' -or
             $msg -match 'Forbidden' -or
             $msg -match 'insufficient' -or
             $msg -match 'does not have authorization' -or
             $msg -match 'BadRequest')

        if ($isBillingRestricted) {
            $subName = $sub.Name
            $subId   = $sub.Id
            $acctId  = $acct.Id
            $tenId   = $tenant.Id

            $pretty = @"
Consumption usage data could not be retrieved for this subscription due to billing/cost access restrictions.

Subscription : $subName ($subId)
Account      : $acctId
Tenant       : $tenId
Cmdlet       : Get-AzConsumptionUsageDetail
Dates (UTC)  : $($StartDate.ToString("yyyy-MM-dd")) .. $($EndDate.ToString("yyyy-MM-dd"))
Error        : $($ex.GetType().FullName)
Category     : $cat
FQID         : $fqid
Status/Code  : $status / $errorCode
Message      : $msg

What this usually means:
- The identity running the script has RBAC on resources/subscription but NOT the billing/cost permissions needed for Consumption/Cost Management.
- Ensure the identity has 'Cost Management Reader' (or equivalent billing role) at the correct scope (subscription/billing scope).
- Some billing account types/scopes do not support all billing/consumption operations; access may require additional authorization.
"@

            Write-Warning $pretty

            # Return an empty array so downstream logic can continue gracefully
            return @()
        }

        # If it's some other failure, rethrow (preserve original)
        throw
    }
}




## Cleanup
 

 $recommendationresults = ''

 $Subscriptionconsumptionreport = ''

$subs = get-Azsubscription 

$startDate = (Get-Date).AddDays(-90)
$endDate = Get-Date
 


foreach($sub in $subs)
{
    $subname = $sub.Name

   

        Set-Azcontext -Subscription $subname   

 

    #    $costData = Get-AzConsumptionUsageDetail -StartDate $startDate -EndDate $endDate  | SELECT -Property * -erroraction silentlycontinue
 
$costData = Get-ConsumptionUsageDetailSafe -StartDate $startDate -EndDate $endDate
if (-not $costData -or $costData.Count -eq 0) {
    Write-Warning "No consumption records returned (likely billing access restriction). Skipping cost enrichment and continuing with Advisor-only output."
    # or: return; / exit 2
}

  
 
$advisorRecommendations = Get-AzAdvisorRecommendation -SubscriptionId $sub.Id 
#$advisorRecommendations #   | Export-Csv -Path C:\Recommendations.csv


    foreach($recommendation in $advisorRecommendations)
    {
    

 
    $recommendationamount = Get-AzAdvisorRecommendation -resourceid $($recommendation.Id) | Select-Object -ExpandProperty ExtendedProperty | select *
    
    $($recommendationamount.Properties.CostSavings).amount



        $recommendationobj = new-object PSobject 

        $resourcename = $($recommendation.ResourceMetadataResourceId).Split('/')[-1]


   
                 $extendedProperties = $recommendation.ExtendedProperty | select *
 
                #Write-Host "Keys for recommendation $($recommendation.Id):"
<#
                foreach ($key in $extendedProperties) {



                        $keymetadata = $($key.keys) -split(' ') 
                        $valuedata = $($key.values) -split(' ') 
                        $($keymetadata).count 
#>
             if( $($extendedProperties.AdditionalProperties.Keys) -like '*Savings*')
                    {
                         $extendedProperties.AdditionalProperties.GetEnumerator() | foreach-object  {

                         $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  $($_.key)  -Value  $($_.value)


                            Write-Host "  $($_.key)    $($_.value) "
                        }
                    }
               
  

 ################


            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Action  -Value  $($RECOMMENDATION.Action)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Category  -Value  $($RECOMMENDATION.Category)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Description  -Value  $($RECOMMENDATION.Description)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ExposedMetadataProperty  -Value  $($RECOMMENDATION.ExposedMetadataProperty)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ExtendedProperty  -Value  $($RECOMMENDATION.ExtendedProperty)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Id  -Value  $($RECOMMENDATION.Id)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Impact  -Value  $($RECOMMENDATION.Impact)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ImpactedField  -Value  $($RECOMMENDATION.ImpactedField)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ImpactedValue  -Value  $($RECOMMENDATION.ImpactedValue)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Label  -Value  $($RECOMMENDATION.Label)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  LastUpdated  -Value  $($RECOMMENDATION.LastUpdated)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  LearnMoreLink  -Value  $($RECOMMENDATION.LearnMoreLink)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Metadata  -Value  $($RECOMMENDATION.Metadata)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Name  -Value  $($RECOMMENDATION.Name)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  PotentialBenefit  -Value  $($RECOMMENDATION.PotentialBenefit)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  RecommendationTypeId  -Value  $($RECOMMENDATION.RecommendationTypeId)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Remediation  -Value  $($RECOMMENDATION.Remediation)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ResourceGroupName  -Value  $($RECOMMENDATION.ResourceGroupName)

            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  resourcename  -Value  $resourcename

            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ResourceMetadataAction  -Value  $($RECOMMENDATION.ResourceMetadataAction)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ResourceMetadataPlural  -Value  $($RECOMMENDATION.ResourceMetadataPlural)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ResourceMetadataResourceId  -Value  $($RECOMMENDATION.ResourceMetadataResourceId)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ResourceMetadataSingular  -Value  $($RECOMMENDATION.ResourceMetadataSingular)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ResourceMetadataSource  -Value  $($RECOMMENDATION.ResourceMetadataSource)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Risk  -Value  $($RECOMMENDATION.Risk)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ShortDescriptionProblem  -Value  $($RECOMMENDATION.ShortDescriptionProblem)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  ShortDescriptionSolution  -Value  $($RECOMMENDATION.ShortDescriptionSolution)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  SuppressionId  -Value  $($RECOMMENDATION.SuppressionId)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Type  -Value  $($RECOMMENDATION.Type)
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  UsageQuantity  -Value  $newusage
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Originalcost  -Value  [decimal]$originalcost
            $RECOMMENDATIONobj  | add-member -MemberType NoteProperty -Name  Newcost  -Value  [decimal]$Newcost

            [ARRAY]$recommendationresults += $recommendationobj
         
 

    }
     
            $Subscriptionconsumptiondetails = Get-AzConsumptionUsageDetail -Expand MeterDetails -erroraction "silentlycontinue"

            foreach($Subscriptionconsumptiondetail in $Subscriptionconsumptiondetails)
            {

            $usageconsumptionobj = new-object PSObject 



                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  AccountName  -Value  $($Subscriptionconsumptiondetail.AccountName)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  AdditionalInfo  -Value  $($Subscriptionconsumptiondetail.AdditionalInfo)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  AdditionalProperties  -Value  $($Subscriptionconsumptiondetail.AdditionalProperties)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  BillableQuantity  -Value  $($Subscriptionconsumptiondetail.BillableQuantity)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  BillingPeriodId  -Value  $($Subscriptionconsumptiondetail.BillingPeriodId)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  BillingPeriodName  -Value  $($Subscriptionconsumptiondetail.BillingPeriodName)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  ConsumedService  -Value  $($Subscriptionconsumptiondetail.ConsumedService)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  CostCenter  -Value  $($Subscriptionconsumptiondetail.CostCenter)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  Currency  -Value  $($Subscriptionconsumptiondetail.Currency)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  DepartmentName  -Value  $($Subscriptionconsumptiondetail.DepartmentName)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  Id  -Value  $($Subscriptionconsumptiondetail.Id)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  InstanceId  -Value  $($Subscriptionconsumptiondetail.InstanceId)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  InstanceLocation  -Value  $($Subscriptionconsumptiondetail.InstanceLocation)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  InstanceName  -Value  $($Subscriptionconsumptiondetail.InstanceName)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  InvoiceId  -Value  $($Subscriptionconsumptiondetail.InvoiceId)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  InvoiceName  -Value  $($Subscriptionconsumptiondetail.InvoiceName)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  IsEstimated  -Value  $($Subscriptionconsumptiondetail.IsEstimated)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  MeterDetails  -Value  $($Subscriptionconsumptiondetail.MeterDetails)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  MeterId  -Value  $($Subscriptionconsumptiondetail.MeterId)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  Name  -Value  $($Subscriptionconsumptiondetail.Name)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  PretaxCost  -Value  $($Subscriptionconsumptiondetail.PretaxCost)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  Product  -Value  $($Subscriptionconsumptiondetail.Product)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  SubscriptionGuid  -Value  $($Subscriptionconsumptiondetail.SubscriptionGuid)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  SubscriptionName  -Value  $($Subscriptionconsumptiondetail.SubscriptionName)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  Tags  -Value  $($Subscriptionconsumptiondetail.Tags)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  Type  -Value  $($Subscriptionconsumptiondetail.Type)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  UsageEnd  -Value  $($Subscriptionconsumptiondetail.UsageEnd)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  UsageQuantity  -Value  $($Subscriptionconsumptiondetail.UsageQuantity)
                $usageconsumptionobj  | add-member -MemberType NoteProperty -Name  UsageStart  -Value  $($Subscriptionconsumptiondetail.UsageStart)


            [array]$Subscriptionconsumptionreport += $usageconsumptionobj
            }


}



$resultsfilename = 'advisiordata.csv'
$resultsfilename1 = 'subscriptionusageconsumptiondetails.csv'

##########################################

 $recommendationresults |  Select  Action,`
Category,`
Description,`
ExposedMetadataProperty,`
ExtendedProperty,`
Id,`
Impact,`
ImpactedField,`
ImpactedValue,`
Label,`
LastUpdated,`
LearnMoreLink,`
Metadata,`
Name,`
PotentialBenefit,`
RecommendationTypeId,`
Remediation,`
ResourceGroupName,`
Resourcename,`
ResourceMetadataAction,`
ResourceMetadataPlural,`
ResourceMetadataResourceId,`
ResourceMetadataSingular,`
ResourceMetadataSource,`
Risk,`
ShortDescriptionProblem,`
ShortDescriptionSolution,`
SuppressionId,`
Type,`
UsageQuantity,`
 MaxCpuP95, `
 MaxTotalNetworkP95, `
 MaxMemoryP95, `
savingsAmount, `
annualSavingsAmount, `
savingsCurrency, `
deploymentId, `
roleName, `
currentSku, `
targetSku, `
recommendationMessage, `
recommendationType, `
regionId, `
subscriptionId, `
Duration `
| export-csv c:\temp\advisor_recommendations_and_Savings.csv  -notypeinformation 


##########################################



 $recommendationresults |  Select  Action,`
Category,`
Description,`
ExposedMetadataProperty,`
ExtendedProperty,`
Id,`
Impact,`
ImpactedField,`
ImpactedValue,`
Label,`
LastUpdated,`
LearnMoreLink,`
Metadata,`
Name,`
PotentialBenefit,`
RecommendationTypeId,`
Remediation,`
ResourceGroupName,`
Resourcename,`
ResourceMetadataAction,`
ResourceMetadataPlural,`
ResourceMetadataResourceId,`
ResourceMetadataSingular,`
ResourceMetadataSource,`
Risk,`
ShortDescriptionProblem,`
ShortDescriptionSolution,`
SuppressionId,`
Type,`
UsageQuantity,`
 MaxCpuP95, `
 MaxTotalNetworkP95, `
 MaxMemoryP95, `
savingsAmount, `
annualSavingsAmount, `
savingsCurrency, `
deploymentId, `
roleName, `
currentSku, `
targetSku, `
recommendationMessage, `
recommendationType, `
regionId, `
subscriptionId, `
Duration `
| export-csv $resultsfilename -notypeinformation 


###################################################

$Subscriptionconsumptionreport | Select AccountName,`
AdditionalInfo,`
AdditionalProperties,`
BillableQuantity,`
BillingPeriodId,`
BillingPeriodName,`
ConsumedService,`
CostCenter,`
Currency,`
DepartmentName,`
Id,`
InstanceId,`
InstanceLocation,`
InstanceName,`
InvoiceId,`
InvoiceName,`
IsEstimated,`
MeterDetails,`
MeterId,`
Name,`
PretaxCost,`
Product,`
SubscriptionGuid,`
SubscriptionName,`
Tags,`
Type,`
UsageEnd,`
UsageQuantity,`
UsageStart | export-csv $resultsfilename1 -NoTypeInformation 




 

 ##### storage subinfo

 try
{
    "Logging in to Azure..."
   Connect-AzAccount -identity #-Environment AzureUSGovernment # -Identity
  
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}


##### storage subinfo

$Region = "<location>"
#####  Subscription name if results storage accounts are in a separate subscription

### If results storage account is in a separate tenant 
#Connect-azaccount   # for storage account tenant and subscription context verification

 $subscriptionselected = '<results subscription>'



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'savingsrecommendations'
 
### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)


 Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowBlobPublicAccess $true -AllowSharedKeyAccess $true  -force
 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose -ErrorAction SilentlyContinue
 
     
        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  -StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  -StorageAccountName $storageaccountname `
                                        -StorageAccountKey $StorageKey


             #Upload user.csv to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext -ErrorAction SilentlyContinue
                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       

          Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -force



################################################

$storageaccountname = 'consumption'
$storagecontainer = 'usageconsumptiondetails'


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose -ErrorAction SilentlyContinue
 
     
        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  -StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  -StorageAccountName $storageaccountname `
                                        -StorageAccountKey $StorageKey


             #Upload user.csv to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext -ErrorAction SilentlyContinue
                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       






        
          Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename1  -File $resultsfilename1 -Context $destContext -force
      
     











