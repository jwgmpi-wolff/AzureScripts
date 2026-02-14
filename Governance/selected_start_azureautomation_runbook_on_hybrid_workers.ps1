
 import-module az.automation #-verbose
 
$azcontext = Connect-AzAccount -Identity

 $subscriptionaname = "wolffentpsub"
 $subscriptionid = get-azsubscription -SubscriptionName $subscriptionaname |select id
 


Set-AzContext -SubscriptionId $($subscriptionid.id)

 
$resourceGroupName = "jwgovernance"
$automationAccountName = "wolffentpautoact"
$hybridRunbookWorkerGroupName = "wolffhybridworkergroup"



########### Authenticating 

Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
try {
    $AzureLogin = Get-AzSubscription -SubscriptionId $($subscriptionid.id)
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken -AsSecureString
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token.Token))
    if ($token.ExpiresOn -lt (Get-Date)) {
        Write-Host "Logging you out due to cached token is expired for REST AUTH. Re-run script"
        $null = Disconnect-AzAccount
    }
} catch {
    $null = Login-AzAccount
    $AzureLogin = Get-AzSubscription -SubscriptionId $($subscriptionid.id)
    $currentContext = Get-AzContext
    $token = Get-AzAccessToken -AsSecureString
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token.Token))
}


$scheduledjobs = Get-AzAutomationScheduledRunbook -ResourceGroupName jwgovernance -AutomationAccountName wolffentpautoact -RunbookName "get_available_resource_Skus_pergions_core_and_ram" | where HybridWorker -ne ''



############# Get the list of Hybrid Workers
$uri = "https://management.azure.com/subscriptions/$($subscriptionid.id)/resourceGroups/$resourceGroupName/providers/Microsoft.Automation/automationAccounts/$automationAccountName/hybridRunbookWorkerGroups/$hybridRunbookWorkerGroupName/hybridRunbookWorkers?api-version=2023-11-01"
$headers = @{
    "Authorization" = "Bearer $plainToken"
}
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

# Check the status of each Hybrid Worker and start if stopped

foreach ($worker in $response.value) {
    if ($worker.properties.status -ne "Running") {
        get-azvm -Name $($worker.properties.workerName) | start-azvm  
 
        Write-Host "Started Hybrid Worker: $($worker.properties.workerName)"
    } else {
        Write-Host "Hybrid Worker: $($worker.name) is already running."
    }
}
 
 ### run runbook job in hyrbid worker

 $runbooks = get-AzAutomationRunbook -ResourceGroupName jwgovernance -AutomationAccountName wolffentpautoact -Name "get_available_resource_Skus_pergions_core_and_ram"

 foreach($runbookid in  $runbooks )
 {
    Start-AzAutomationRunbook -Name $($runbookid.Name) -RunOn $hybridRunbookWorkerGroupName -ResourceGroupName $resourceGroupName  -AutomationAccountName $automationAccountName 
     
 $running = (Get-AzAutomationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName | Select-Object JobId, status)
} 

 $running
 













