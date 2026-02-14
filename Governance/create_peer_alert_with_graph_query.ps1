# Connect to your cloud service account
$context = Connect-AzAccount -identity

$sub = get-azsubscription -subscriptionname $($context.subscription) | select -first 1

# Define the resource group and action group names
$resourceGroupName = "jwgovernance"
$actionGroupName = "wolffactiongroup"

   $actiongroup = Get-AzActionGroup | Where-Object { $_.Name -eq $actionGroupName }


$emailReceiver =   "jerrywolff@microsoft.com"

 $receivername = New-AzActionGroupEmailReceiverObject    -EmailAddress $emailReceiver -Name $emailReceiver
 
 $scope = "/subscriptions/$($sub.id)"
 



$Message = ''

# Define the query to find resources with potential cost issues
$query = @"
resources
| where type =~ 'microsoft.network/virtualNetworks'
| mv-expand peering = properties.virtualNetworkPeerings
| where isnotempty(peering)
| summarize totalPeeringCount = count()
| extend AlertName = "Virtual Network Peering Count Alert"
| extend Severity = "Sev3"
| extend Description = "Alert when the count of network peers is detected."
| extend AlertMessage = iff(totalPeeringCount >= 400, "Warning: Total peering count is nearing the limit of 500.", "Total peering count is within safe limits.")
"@

# Run the query
$results = Search-AzGraph -Query $query

# Display the results
$resultmessage = $results   




#$resultmessage | fl *

$resultobj = new-object PSObject

$resultobj | add-member -MemberType NoteProperty -Name  totalPeeringCount    -value $($resultmessage.totalPeeringCount)
$resultobj | add-member -MemberType NoteProperty -Name  AlertName     -value $($resultmessage.AlertName)
$resultobj | add-member -MemberType NoteProperty -Name  Severity     -value $($resultmessage.Severity)
$resultobj | add-member -MemberType NoteProperty -Name  AlertMessage     -value $($resultmessage.AlertMessage)

[array]$Message += $resultobj


############

function sendalert 
{
           $location = 'Global'
            # Create the activity log alert condition
            $condition1 = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject -Field "category" -Equal "ServiceHealth"
            $condition2 = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject -Field "operationName" -Equal "Microsoft.Network/register/action"
 
           $actionGroupsHashTable = @{
            Id = $($actiongroup.Id)
            EmailSubject = "Alert Notification"
            EmailTo = "JERRYWOLFF@MICROSOFT.COM"
            WebhookProperty = ""
        }
 
 # Create the activity log alert
New-AzActivityLogAlert `
    -Name "$($message.alertname)" `
    -location $location `
    -ResourceGroupName $resourceGroupName `
    -Scope $scope `
    -Action $actionGroupsHashTable `
    -Condition $condition1, $condition2 `
    -Description "Peering count approaching max limit of 10 current count is: $($message.totalPeeringCount)" `
    -Enabled $true

}
$actionGroupsHashTable = @{
    Id = $($actiongroup.Id)
    EmailSubject = "Alert Notification"
    EmailTo = "user@example.com"
    WebhookProperty = ""
}
if($($Message.totalpeeringcount) -ge 6)
{
    
  sendalert 

}


Get-AzActivityLogAlert -Name "Virtual Network Peering Count Alert" -ResourceGroupName $resourceGroupName -SubscriptionId $($SUB.ID)





