
 import-module az.automation #-verbose
 

$azcontext = Connect-AzAccount -Identity
 
 $subscriptionaname = "wolffentpsub"
 $subscriptionid = get-azsubscription -SubscriptionName $subscriptionaname
 
 
$resourceGroupName = "jwgovernance"
$automationAccountName = "wolffentpautoact"
$hybridRunbookWorkerGroupName = "wolffhybridworkergroup"

 
 set-azcontext -Subscription  $subscriptionaname



 $runbooks = get-AzAutomationRunbook -ResourceGroupName jwgovernance -AutomationAccountName wolffentpautoact -Name "servicehealthEvents"

 foreach($runbookid in  $runbooks )
 {
    Start-AzAutomationRunbook -Name $($runbookid.Name) -RunOn $hybridRunbookWorkerGroupName -ResourceGroupName $resourceGroupName  -AutomationAccountName $automationAccountName 
     
 $running = (Get-AzAutomationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName | Select-Object JobId, status)
} 


 












