$azcontext = Connect-AzAccount -Identity

$subscriptionName = "wolffentpsub"
$subscriptionId = (Get-AzSubscription -SubscriptionName $subscriptionName).Id

Set-AzContext -SubscriptionId $subscriptionId

$resourceGroupName = "jwgovernance"
$automationAccountName = "wolffentpautoact"
$hybridRunbookWorkerGroupName = "wolffhybrgroup2"

Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
try {
    $AzureLogin = Get-AzSubscription -SubscriptionId $subscriptionId
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken -AsSecureString
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token.Token))
    if ($token.ExpiresOn -lt (Get-Date)) {
        Write-Host "Logging you out due to cached token is expired for REST AUTH. Re-run script"
        $null = Disconnect-AzAccount
    }
} catch {
    $null = Login-AzAccount -Identity
    $AzureLogin = Get-AzSubscription -SubscriptionId $subscriptionId
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken -AsSecureString
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token.Token))
}

# Get the list of Hybrid Workers
$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Automation/automationAccounts/$automationAccountName/hybridRunbookWorkerGroups/$hybridRunbookWorkerGroupName/hybridRunbookWorkers?api-version=2023-11-01"
$headers = @{
    "Authorization" = "Bearer $plainToken"
}
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -UseBasicParsing

# Check the status of each Hybrid Worker and start if stopped
foreach ($worker in $response.value) {
    if ($worker.properties.status -ne "Running") {
        Get-AzVM -Name $($worker.properties.workerName) | Start-AzVM  
        Write-Host "Started Hybrid Worker: $($worker.properties.workerName)"
    } else {
        Write-Host "Hybrid Worker: $($worker.name) is already running."
    }
}


