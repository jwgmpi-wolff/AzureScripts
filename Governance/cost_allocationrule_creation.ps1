####https://management.azure.com/providers/Microsoft.Billing/billingAccounts/8611537/providers/Microsoft.Consumption/usagedetails?api-version=2019-10-01



# Connect to Azure account
Connect-AzAccount  -Identity 

# Define the parameters for the allocation rule
$allocationRuleName = "MyAllocationRule"
$resourceGroupName = "MyResourceGroup"
$subscriptionId = "YourSubscriptionId"
$allocationPercentage = 50 # Percentage to allocate

# Create or update the allocation rule
New-AzCostManagementAllocationRule -Name $allocationRuleName `
-ResourceGroupName $resourceGroupName `
-SubscriptionId $subscriptionId `
-AllocationPercentage $allocationPercentage

# Verify the allocation rule
Get-AzCostManagementAllocationRule -Name $allocationRuleName `
-ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId


$subs = get-azsubscription -SubscriptionId 64e355d7-997c-491d-b0c1-8414dccfcf42  

foreach($sub in $subs) 
{
set-azcontext -Subscription $($sub.name)  
get-azreservation
}






