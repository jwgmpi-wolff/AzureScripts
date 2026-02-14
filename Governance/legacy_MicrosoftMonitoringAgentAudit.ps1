

# Connect to Azure
Connect-AzAccount -Identity

$subs = get-azsubscription



$extensionData = ''
    $extensionData = @()

foreach($sub in $subs)
{

    set-azcontext -subscription $($sub.name) 

    # Get all virtual machines
    $vms = Get-AzVM 

    # Create an array to store extension data


    # Loop through each virtual machine and get its extensions
    foreach ($vm in $vms) {
        $vmName = $vm.Name
        $resourceGroup = $vm.ResourceGroupName
        $extensions = Get-AzVMExtension -ResourceGroupName $resourceGroup -VMName $vmName -Status
        foreach ($extension in $extensions) {
        $subscription = $($extension.id) -split('/') 
       # $subscription[2]
        $subscrptionname = (get-azsubscription -SubscriptionId $($subscription[2])).Name


            $extensionData += [PSCustomObject]@{
                VirtualMachine = $vmName
                ExtensionName = $extension.Name
                Publisher = $extension.Publisher
                Version = $extension.Version
                ProvisioningState = $extension.ProvisioningState
                Status = $extension.EnableAutomaticUpgrade
                Resourcegroup = $extension.ResourceGroupName
                Subscriptionid = $subscription[2] 
                Subscriptionname = $subscriptionname
            }
        }
    }

}
# Display the extension data in a table
$extensionData | Format-Table -AutoSize




$monitoringagentexists = $extensionData | where ExtensionName -eq 'MicrosoftMonitoringAgent' | select  VirtualMachine `
       ,ExtensionName `
      ,Publisher `
      ,Version `
      ,ProvisioningState `
      ,Status `
      ,Resourcegroup `
      ,Subscriptionname `
      ,Subscriptionid



  ###GENERATE HTML Output for review        
 
    $CSS = @" 
   MicrosoftMonitoringAgent Audit $date
<Title> MicrosoftMonitoringAgent Audit $date Report: $date </Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	border-top: 1px solid #4B0082;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #4B0082;
}
</Style>
"@


 

 

 ((($monitoringagentexists| SELECT  VirtualMachine `
       ,ExtensionName `
      ,Publisher `
      ,Version `
      ,ProvisioningState `
      ,Status `
      ,Resourcegroup `
      ,Subscriptionname `
      ,Subscriptionid `
 | `
ConvertTo-Html -Head $CSS ).replace("False","<font color=red>False</font>")).replace("True","<font color=green>True</font>"))| out-file "C:\TEMP\MicrosoftMonitoringAgentAudit.html"
Invoke-Item    "C:\TEMP\MicrosoftMonitoringAgentAudit.html"                                                                                                     





#MicrosoftMonitoringAgent

