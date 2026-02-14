Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'

import-module -Name az.billing -force -ErrorAction SilentlyContinue
import-module -Name az.advisor -force -ErrorAction SilentlyContinue
import-module -name Az.Reservations -force -ErrorAction SilentlyContinue

$null = connect-AzAccount -id

function BuildBody {
    param (
        [parameter(mandatory=$True)]
        [string]$method
    )
    return @{
        Headers = @{
            Authorization = "Bearer $($token.token)"
            'Content-Type' = 'application/json'
        }
        Method = $method
        UseBasicParsing = $true
    }
}

function Add-IndexNumberToArray {
    param (
        [Parameter(Mandatory=$True)]
        [array]$array
    )
    for ($i = 0; $i -lt $array.Count; $i++) {
        Add-Member -InputObject $array[$i] -Name "#" -Value ($i + 1) -MemberType NoteProperty
    }
    return $array
}

$usageresponse = ''
$costreport = ''
$response = ''
$token = ''
$today = Get-Date -Format 'yyyyMM'
$month = 1
$numberofmonths = 5
$date = (Get-Date).AddMonths(-$numberofmonths)
$datestart = Get-Date $date -Format 'yyyyMM'

$subscriptions = Get-AzSubscription

foreach ($subscription in $subscriptions) {
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    try {
        $AzureLogin = Get-AzSubscription
        $currentContext = Get-AzContext
        $token = Get-AzAccessToken -TenantId $subscription.TenantId
        if ($token.ExpiresOn -lt (Get-Date)) {
            Write-Host "Logging you out due to cached token expiration. Re-run script."
            # $null = Disconnect-AzAccount
        }
    } catch {
        $AzureLogin = Get-AzSubscription
        $currentContext = Get-AzContext
        $token = Get-AzAccessToken -TenantId $token.TenantId
    }

    $Start = (Get-Date $date -Hour 0 -Minute 0 -Second 0).ToString("yyyy-MM-ddThh:mm:ssZ")
    $End = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddThh:mm:ssZ")
    $body = BuildBody -method "GET"

    Set-AzContext -Subscription $subscription.Name

    $tenantId = $subscription.TenantId
    $billingScope = $subscription.Id
    $billingaccount = ((Get-AzBillingAccount).Id -split '/')[ -1 ]

    $requestUri = "https://management.azure.com/subscriptions/$billingScope/providers/Microsoft.CostManagement/query?api-version=2024-08-01"

    try {
        $response = Invoke-RestMethod -Uri $requestUri -Headers $body.Headers -Method GET -ErrorAction SilentlyContinue
        if ($response -ne $null) {
            ($response.value).properties | Export-Csv -Path "savingsrecommendations.csv" -NoTypeInformation -Append
        } else {
            Write-Error "Response is null. Please check the request URI and headers."
        }
    } catch {
        Write-Error $_.Exception.Message
    }

    $usagerequesturi = "https://management.azure.com/subscriptions/$billingScope/providers/Microsoft.Consumption/usageDetails?api-version=2018-03-31&$expand=properties/additionalProperties"

    try {
        $usageresponse = Invoke-RestMethod -Uri $usagerequesturi -Headers $body.Headers -Method GET -ErrorAction SilentlyContinue
        if ($usageresponse -ne $null) {
            ($usageresponse.value).properties | Export-Csv -Path "billingdata.csv" -NoTypeInformation
        } else {
            Write-Error "Usage response is null. Please check the request URI and headers."
        }
    } catch {
        Write-Error $_.Exception.Message
    }
}

# Storage account setup and data upload
$Region = "west us"
$subscriptionselected = 'wolffentpsub'
$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = Get-AzSubscription -SubscriptionName $subscriptionselected
$TenantID = $subscriptioninfo.TenantId
$storageaccountname = 'wolffautosa'

Set-AzContext -Subscription $subscriptioninfo.Name -Tenant $TenantID

 ## un block storage 
# Enable Allow Storage Account Key Access
$scope = "/subscriptions/$($subscriptioninfo.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

$servicePrincipal = Get-AzADServicePrincipal -DisplayName "$($azcontext.Account)"

# Display the service principal's Object ID
$servicePrincipal.Id

 

Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname   -AllowSharedKeyAccess $true  -force

 $destContext = New-AzStorageContext -StorageAccountName "$storageaccountname" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$resourcegroupname" -Name $storageaccountname).Value | select -first 1)



$storagecontainer = 'billingcosts'
$resultsfilename = "billingdata.csv"

try {
    if (-not (Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname)) {
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageaccountname Now"
        New-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -Location $Region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write"} -Verbose
    }
} catch {
    Write-Host "Storage Account Already Exists, Skipping Creation of $storageaccountname"
}

$StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname -StorageAccountName $storageaccountname).Value | Select-Object -First 1
$destContext = New-AzStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $StorageKey

try {
    if (-not (Get-AzStorageContainer -Name $storagecontainer -Context $destContext)) {
        New-AzStorageContainer -Name $storagecontainer -Context $destContext
    }
} catch {
    Write-Warning "$storagecontainer container already exists"
}

Set-AzStorageBlobContent -Container $storagecontainer -Blob $resultsfilename -File $resultsfilename -Context $destContext -Force

# Savings recommendations
$storagecontainer = 'savingsrecommendations'
$resultsfilename1 = "savingsrecommendations.csv"

try {
    if (-not (Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname)) {
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageaccountname Now"
        New-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -Location $Region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write"} -Verbose
    }
} catch {
    Write-Host "Storage Account Already Exists, Skipping Creation of $storageaccountname"
}

$StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname -StorageAccountName $storageaccountname).Value | Select-Object -First 1
$destContext = New-AzStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $StorageKey

try {
    if (-not (Get-AzStorageContainer -Name $storagecontainer -Context $destContext)) {
        New-AzStorageContainer -Name $storagecontainer -Context $destContext
    }
} catch {
    Write-Warning "$storagecontainer container already exists"
}

Set-AzStorageBlobContent -Container $storagecontainer -Blob $resultsfilename1 -File $resultsfilename1 -Context $destContext -Force
