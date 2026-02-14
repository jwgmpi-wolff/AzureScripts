
# Connect to Azure account
   #$account =  Connect-AzAccount   -UseDeviceAuthentication -Tenant 72f988bf-86f1-41af-91ab-2d7cd011db47   -SubscriptionName 'Trey Research Finance'
 connect-azaccount  -identity
 
 $account | fl *

# Set the subscription context if you have multiple subscriptions
#$subscriptions = Get-AzSubscription # -TenantId 72f988bf-86f1-41af-91ab-2d7cd011db47 -SubscriptionName 'Trey Research Finance'
$subscriptions = Get-AzSubscription -SubscriptionName wolffentpsub  # -TenantId 72f988bf-86f1-41af-91ab-2d7cd011db47 -SubscriptionName 'Trey Research Finance'



 $advisorsavingsreport = ''


 
    $QUERY =  'advisorresources
| where type == "microsoft.advisor/recommendations"
| where tostring (properties.category) has "Cost"
| where properties.impactedField has "Microsoft.Subscriptions/subscriptions" 
| project name, AffectedResource=tostring(properties.resourceMetadata.resourceId),Recommendation=tostring(properties.shortDescription.problem),Impact=tostring(properties.impact),resourceGroup,AdditionaInfo=properties.extendedProperties,subscriptionId'
	
    
    $queryresults1 =  Search-AzGraph -Query $QUERY -Subscription $SUB.id

    $($queryresults1.AdditionaInfo) | FL *


      # Function to calculate savings for different periods
    function Calculate-Savings {
        param (
            [float]$NetSavings,
            [string]$Term,
            [int]$Days
        )

        if ($Term -eq 'P1Y') {
            $termtotalsavings = $NetSavings
        } elseif ($Term -eq 'P3Y') {
            $termtotalsavings = $NetSavings / 3
        } else {
            $termtotalsavings = 0
        }

        $dailySavings = $termtotalsavings / 365
        return $dailySavings * $Days
    }



    $reservationrecommendations = ''
     


      $($queryresults1) | FL *

      foreach($reservationitem in $($queryresults1) )
      {
        

            $reservobj = new-object PSObject
            $($reservationitem.name)

            $netSavings = $($reservationitem.AdditionaInfo.annualSavingsAmount)

                $reservobj | add-member -MemberType NoteProperty  -name Recommendationname     -value  $($reservationitem.name)
                $reservobj | add-member -MemberType NoteProperty  -name AffectedResource     -value  $($reservationitem.AffectedResource)
                $reservobj | add-member -MemberType NoteProperty  -name Recommendation     -value  $($reservationitem.Recommendation)
                $reservobj | add-member -MemberType NoteProperty  -name Impact     -value  $($reservationitem.Impact)
                $reservobj | add-member -MemberType NoteProperty  -name resourceGroup     -value  $($reservationitem.resourceGroup)                
                $reservobj | add-member -MemberType NoteProperty  -name AdditionaInfo     -value  $($reservationitem.AdditionaInfo)
                $reservobj | add-member -MemberType NoteProperty  -name subscriptionId     -value  $($reservationitem.subscriptionId)
 
                $reservobj | Add-Member -MemberType NoteProperty -Name region -Value $($reservationitem.AdditionaInfo.region)
                $reservobj | Add-Member -MemberType NoteProperty -Name reservedResourceType -Value $($reservationitem.AdditionaInfo.reservedResourceType)
                $reservobj | Add-Member -MemberType NoteProperty -Name annualSavingsAmountbyterm -Value $($reservationitem.AdditionaInfo.annualSavingsAmount)
                $reservobj | Add-Member -MemberType NoteProperty -Name savingsCurrency -Value $($reservationitem.AdditionaInfo.savingsCurrency)
                $reservobj | Add-Member -MemberType NoteProperty -Name lookbackPeriod -Value $($reservationitem.AdditionaInfo.lookbackPeriod)
                $reservobj | Add-Member -MemberType NoteProperty -Name savingsAmount -Value $($reservationitem.AdditionaInfo.savingsAmount)
                $reservobj | Add-Member -MemberType NoteProperty -Name targetResourceCount -Value $($reservationitem.AdditionaInfo.targetResourceCount)
                $reservobj | Add-Member -MemberType NoteProperty -Name displaySKU -Value $($reservationitem.AdditionaInfo.displaySKU)
                $reservobj | Add-Member -MemberType NoteProperty -Name displayQty -Value $($reservationitem.AdditionaInfo.displayQty)
                $reservobj | Add-Member -MemberType NoteProperty -Name location -Value $($reservationitem.AdditionaInfo.location)
                $reservobj | Add-Member -MemberType NoteProperty -Name vmSize -Value $($reservationitem.AdditionaInfo.vmSize)
                $reservobj | Add-Member -MemberType NoteProperty -Name subId -Value $($reservationitem.AdditionaInfo.subId)
                $reservobj | Add-Member -MemberType NoteProperty -Name scope -Value $($reservationitem.AdditionaInfo.scope)
                $term = $($reservationitem.AdditionaInfo.term) 

                $reservobj | Add-Member -MemberType NoteProperty -Name term -Value $($reservationitem.AdditionaInfo.term)   
                $reservobj | Add-Member -MemberType NoteProperty -Name sku -Value $($reservationitem.AdditionaInfo.sku)
                 $reservobj | Add-Member -MemberType NoteProperty -Name subscriptionname -Value (Get-azsubscription -subscriptionid $($reservationitem.AdditionaInfo.subId)).name
                $netSavings30Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 30
                $netSavings60Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 60
                $netSavings90Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 90
                $netSavings365Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 365
                $netSavings1095Days = Calculate-Savings -NetSavings $netSavings -Term $term -Days 1095



                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings30Days  -Value $netSavings30Days    
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings60Days  -Value $netSavings60Days
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings90Days  -Value $netSavings90Days
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings365Days  -Value $netSavings365Days
                $reservobj | Add-Member -MemberType NoteProperty -Name netSavings1095Days  -Value $netSavings1095Days


                        
                [array]$reservationrecommendations += $reservobj 

       }
 

                
        # Generate HTML report
$date = Get-Date -Format 'dd MMMM yyyy'
$CSS = @"
<Title> Azure reservation instance Plan Forecast Report from Advisor: $date </Title>
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

$htmlContent = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Total cost of additional hours to zero overages: $$totalCostToZeroOverages</p>
"@ + ( $reservationrecommendations | select Recommendationname,`
AffectedResource,`
Recommendation,`
Impact ,`
#resourceGroup,`
AdditionaInfo,`
subscriptionId,`
subscriptionname, `
region,`
reservedResourceType,`
term,`
annualSavingsAmountbyterm,`
savingsCurrency,`
lookbackPeriod,`
savingsAmount,`
targetResourceCount,`
displaySKU,`
displayQty,`
location,`
vmSize,`
subId,`
scope,`
sku,`
  netSavings30Days,`    
  netSavings60Days,`
  netSavings90Days,`
  netSavings365Days,`
  netSavings1095Days | ConvertTo-Html -Head $CSS)

$outputHtmlPath = "c:\temp\reservation_plan_from_advisor.html"
$htmlContent | Out-File -FilePath $outputHtmlPath

Write-Output "HTML report has been saved to $outputHtmlPath"

 

# Open the HTML report
Invoke-Item -Path $outputHtmlPath

## Save to csv format 
$reservationrecommendations | Where-Object { $_ -ne "" } | select Recommendationname,`
AffectedResource,`
Recommendation,`
Impact ,`
#resourceGroup,`
AdditionaInfo,`
subscriptionId,`
subscriptionname, `
region,`
reservedResourceType,`
term,`
annualSavingsAmountbyterm,`
savingsCurrency,`
lookbackPeriod,`
savingsAmount,`
targetResourceCount,`
displaySKU,`
displayQty,`
location,`
vmSize,`
subId,`
scope,`
  netSavings30Days,`    
  netSavings60Days,`
  netSavings90Days,`
  netSavings365Days,`
  netSavings1095Days | export-csv -Path "C:\temp\reservation_plan_from_advisor.csv" -NoTypeInformation

############### summary 
# Group the data by AffectedResource, reservedResourceType, term, sku, vmsize, region, and subscriptionname
$groupedData = $reservationrecommendations | where-object {$_ -ne ""} | Group-Object -Property recommendation, AffectedResource, reservedResourceType, term, sku, vmsize, region, subscriptionname

# Create an array to store the summary results
$summaryResults = @()

# Loop through each group and create a custom object for each summary result
foreach ($group in $groupedData) {
    # Initialize variables for total savings
    $totalNetSavings30Days = 0
    $totalNetSavings60Days = 0
    $totalNetSavings90Days = 0
    $totalNetSavings365Days = 0
    $totalNetSavings1095Days = 0

    # Check if the properties exist and calculate the total savings for each group
    if ($group.Group[0].PSObject.Properties['netSavings30Days']) {
        $totalNetSavings30Days = ($group.Group | Measure-Object -Property netSavings30Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings60Days']) {
        $totalNetSavings60Days = ($group.Group | Measure-Object -Property netSavings60Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings90Days']) {
        $totalNetSavings90Days = ($group.Group | Measure-Object -Property netSavings90Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings365Days']) {
        $totalNetSavings365Days = ($group.Group | Measure-Object -Property netSavings365Days -Sum).Sum
    }
    if ($group.Group[0].PSObject.Properties['netSavings1095Days']) {
        $totalNetSavings1095Days = ($group.Group | Measure-Object -Property netSavings1095Days -Sum).Sum
    }

    # Extract the fields correctly
    $fields = $group.Name.Split(',')
    $affectedResource = $fields[0].Trim()
    $reservedResourceType = $fields[1].Trim()
    $term = $fields[2].Trim()
    $sku = $fields[3].Trim()
    $vmsize = $fields[4].Trim()
   # $region = $fields[5].Trim()
    $subscriptionname = $fields[6].Trim()

     # Check if vmsize is blank or null and replace with sku if necessary
    if ([string]::IsNullOrEmpty($vmsize)) { 
        $vmsize = if ([string]::IsNullOrEmpty($group.Group[0].displaysku) -and [string]::IsNullOrEmpty($group.Group[0].location)  ) { 
        $sku = $group.Group[0].sku 
        $term = $fields[1].Trim()
        $vmsize = "All"
        $region = 'All'
        } 
    }
     
    # Handle the case where displaysku is Compute_Savings_Plan
    if ($group.Group[0].displaysku -eq "Compute_Savings_Plan" -or $group.Group[0].displaysku -eq $null) {
        $reservedResourceType = "Compute_Savings_Plan"
        $term = $fields[1].Trim()
        $vmsize = "All"
        $sku = "Compute_Savings_Plan"
        $region = 'All'
    }

    # Debugging output to check values
    Write-Host "AffectedResource: $affectedResource"
    Write-Host "reservedResourceType: $reservedResourceType"
    Write-Host "term: $term"
    Write-Host "sku: $sku"
    Write-Host "vmsize: $vmsize"
    Write-Host "region: $region"
    Write-Host "subscriptionname: $subscriptionname"

    $summaryResult = [PSCustomObject]@{
        AffectedResource      = $affectedResource
        reservedResourceType  = $reservedResourceType
        term                  = $term
        sku                   = $sku
        vmsize                = $vmsize
        region                = $region
        subscriptionname      = $subscriptionname
        Count                 = $group.Count
        netSavings30Days      = $totalNetSavings30Days
        netSavings60Days      = $totalNetSavings60Days
        netSavings90Days      = $totalNetSavings90Days
        netSavings365Days     = $totalNetSavings365Days
        netSavings1095Days    = $totalNetSavings1095Days
        displaysku            = $group.Group[0].sku
        Recommendation         = $($reservationitem.name)
    }
    $summaryResults += $summaryResult
}


 
sl "C:\Users\jerrywolff\OneDrive - Microsoft\Documents\azure\PS1"



foreach($rec in $reservationrecommendations | where subscriptionname -ne $null)
{

write-host "$($rec.name)" -foregroundcolor cyan 


$response =  &  .\wolff_ai_foundry_call_HC_noreasoning_cleanonly.ps1  "provide a recommendation for $($rec)"  *>&1
   
   
 
# 1) Decode HTML entities so &lt;/think&gt; becomes </think>
Add-Type -AssemblyName System.Web
$decoded = [System.Web.HttpUtility]::HtmlDecode($response )

# 2) Find the first closing </think> tag (case-insensitive), and extract everything after it
$pattern = '</think\s*>'            # allows optional whitespace before '>'
$match   = [System.Text.RegularExpressions.Regex]::Match($decoded, $pattern, 'IgnoreCase')

if ($match.Success) {
    $startIndex = $match.Index + $match.Length
    $afterThink = $decoded.Substring($startIndex)
    
    # 3) Trim leading/trailing whitespace
    $result = $afterThink.Trim()

    # 4) (Optional) Normalize Windows/Mac line endings
    $result = $result -replace "`r?`n", "`r`n"


    $resultobj = new-object PSObject 

   

   $resultobj | add-member -MemberType NoteProperty -name subscriptionname -value $($rec.subscriptionname)
   $resultobj | add-member -MemberType NoteProperty -name subscriptionId -value $($rec.subscriptionId)
   $resultobj | add-member -MemberType NoteProperty -name targetResourceCount -value $($rec.targetResourceCount)
   $resultobj | add-member -MemberType NoteProperty -name term -value $($rec.term)
   $resultobj | add-member -MemberType NoteProperty -name vmSize -value $($rec.vmSize)
   $resultobj | add-member -MemberType NoteProperty -name region -value $($rec.region)
   $resultobj | add-member -MemberType NoteProperty -name Recommendationname -value $($rec.Recommendationname)
   $resultobj | add-member -MemberType NoteProperty -name Recommendation -value $($rec.Recommendation)
   $resultobj | add-member -MemberType NoteProperty -name displaySKU -value $($rec.displaySKU)
   $resultobj | add-member -MemberType NoteProperty -name lookbackPeriod -value $($rec.lookbackPeriod)
   $resultobj | add-member -MemberType NoteProperty -name  RESULTGUIDANCE -value "$($result)"

   [array]$aLLRESULTS += $resultobj


    # Output the extracted portion
    #$result
}

}

##########


              
        # Generate HTML report
$date = Get-Date -Format 'dd MMMM yyyy'
$CSS = @"
<Title> Azure reservation instance Plan Forecast Report from Advisor: $date </Title>
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

$htmlContent = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Azure reservation advisor with guidance: </p>
"@ + ( $aLLRESULTS | where subscriptionname -ne $null | select subscriptionname,`
 subscriptionId,`
 targetResourceCount,`
 term,`
 vmSize,`
  region,`
 Recommendationname,`
 Recommendation,`
 displaySKU,`
 lookbackPeriod,`
  RESULTGUIDANCE| ConvertTo-Html -Head $CSS)

$outputHtmlPath = "c:\temp\guidancereservation_plan_from_advisor.html"
$htmlContent | Out-File -FilePath $outputHtmlPath

Write-Output "HTML report has been saved to $outputHtmlPath"

# Open the HTML report
Invoke-Item -Path $outputHtmlPath






