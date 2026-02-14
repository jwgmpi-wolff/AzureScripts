# Login to Azure
Connect-AzAccount


$subs= get-azsubscription 

$i = 0

foreach($sub in $subs)
{
# Select the subscription
Set-AzContext -SubscriptionId "$($sub.Name)"


# Get all automation accounts
$automationAccounts = Get-AzAutomationAccount

foreach($aa in $automationAccounts)
{
    # Get the DSC configurations
    $dscConfigurations = Get-AzAutomationDscConfiguration -ResourceGroupName $aa.ResourceGroupName -AutomationAccountName $aa.AutomationAccountName

    foreach($config in $dscConfigurations)
    {
        $i = $i+1
        # Export the DSC configuration to a file
        $config | Out-File -FilePath "c:\temp\tenant\$($config.Name)_DSC_Configuration$i.txt"
    }
}




}







