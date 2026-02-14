update-module -Name  Az.ApplicationInsights -verbose
import-module  Az.ApplicationInsights 



connect-azaccount -Identity


# Login to Azure - if already logged in, use existing credentials.
Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
try
{
    $AzureLogin = Get-AzSubscription
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken 
    if($Token.ExpiresOn -lt $(get-date))
    {
        "Logging you out due to cached token is expired for REST AUTH.  Re-run script"
        $null = Disconnect-AzAccount        
    } 
}
catch
{
    $null = Login-AzAccount
    $AzureLogin = Get-AzSubscription
    $currentContext = Get-AzContext
 
 
 
 
    $token = Get-AzAccessToken -AsSecureString

}

install-module -Name az.resourcegraph -AllowClobber

 import-module az.resourcegraph 

# MAIN SCRIPT
if ($MyInvocation.MyCommand.Path -ne $null)
{
    $CurrentDir = Split-Path $MyInvocation.MyCommand.Path
}
else
{
    # Sometimes $myinvocation is null, it depends on the PS console host
    $CurrentDir = "."
}
Set-Location $CurrentDir




 
$subscriptions = get-azsubscription  -SubscriptionName 'wolffentpsub'

$subscription = $subscriptions 



set-azcontext -Subscription $($subscription.Name)


$resourceGroup = 'jwgovernance'
$workbookName = '64e7480a-7a22-405f-8892-4e007473c032'

# Construct the API URL with correct api-version
$serviceHealthApi = "https://management.azure.com/subscriptions/$($subscription.Id)/resourceGroups/$resourceGroup/providers/Microsoft.Insights/workbooks/$($workbookName)?api-version=2021-08-01"

Write-Output $serviceHealthApi

# Get an access token
$accessToken = (Get-AzAccessToken).Token

# Define headers
$headers = @{
    'Content-Type'  = 'application/json'
    'Authorization' = "Bearer $accessToken"
}

# Call the API
$response = Invoke-RestMethod -Method GET -Uri $serviceHealthApi -Headers $headers 

# Output the workbook properties
$response.properties

 
$workbooks = $response 
$querylist = ''

foreach($workbook in $workbooks)
{
 

 $workbookpath  = "C:\temp\"
 $workbookname = "$($workbook.name)"
  $workbookdisplayname = "$($workbook.displayname)"

 ###########################################

 $workbookinfo = Get-AzApplicationInsightsWorkbook    -Category 'workbook'  -CanFetchContent  | where-object name -eq $($workbook.Name) | select -property *

 $jsonresource  = $workbookinfo.serializeddata  | convertfrom-json


  
###########################
 
 

foreach($extractedquery in $($jsonresource.items.content)   )
{

 
    write-host "---------------------" -BackgroundColor white
     write-host "$($extractedquery.title)" -BackgroundColor Blue
    write-host "$($extractedquery.query)" -BackgroundColor Yellow   
 

                 $jsoncontentobj = new-object PSObject 

               $contentitems =  $($jsonitem.items.content)  
               $Feature =  $($contentitems.json) -replace('{#','')
     

                $jsoncontentobj | Add-Member -MemberType NoteProperty -Name title -value $($extractedquery.title)     

                $jsoncontentobj | Add-Member -MemberType NoteProperty -Name query -value "$($extractedquery.query)"  
           
 
        
               # $jsoncontentobj
                [array]$querylist +=    $jsoncontentobj

}


 $retirementquery = $($querylist.query)  


 # Raw input string (replace this with your actual input)
#$raw = Get-Content -Path "c:\temp\query.json" -Raw
$raw =  $retirementquery
$advisornotifications = ''
# Step 1: Clean escape sequences
$cleaned = $raw -replace '\\r', '' -replace '\\n', '' -replace '\\t', '' -replace '\\\\', ''

# Step 2: Extract JSON-like objects
$matches = [regex]::Matches($cleaned, '\{.*?\}')

# Step 3: Convert to Kusto-style key-value pairs
foreach ($match in $matches) {

 
        $json = $($match.Value).replace('\','')   | convertfrom-json -ErrorAction ignore

        foreach($notification in $json)
        {
            $notificationobj = new-object PSObject 

         $notificationobj | Add-Member -MemberType NoteProperty -Name ID -value $($notification.ID)
          $notificationobj | Add-Member -MemberType NoteProperty -Name RetiringFeature -value $($notification.RetiringFeature)
           $notificationobj | Add-Member -MemberType NoteProperty -Name RetirementDate -value $($notification.RetirementDate)
            $notificationobj | Add-Member -MemberType NoteProperty -Name Link -value $($notification.Link)
 
        [array]$advisornotifications += $notificationobj
 }

}
$advisornotifications | where id -ne ''

  



(($advisornotifications  | Select -unique    ID,RetiringFeature, RetirementDate,Link    |`
  ConvertTo-Html -Head $CSS ).replace('Â Â','')) | out-file  "c:\temp\$($workbookname)Queries.html"
 invoke-item  "c:\temp\$($workbookname)Queries.html"
 

 $advisornotifications  | Select -unique  ID,RetiringFeature, RetirementDate,Link  |  `
 export-csv "C:\temp\$($workbookname)Queries.csv" -NoTypeInformation

 


 
}
