# Connect to your cloud service account
Connect-AzAccount -identity
Install-Module -Name Az.OperationalInsights -allowclobber
import-module Az.OperationalInsights


# Define the query to find resources with potential cost issues
$rquery = @"
resources
| where type == "microsoft.hybridcompute/machines"  
"@

# Run the query
$results = Search-AzGraph -Query $query


$vmquery = @"
VMComputer
| where VirtualMachineType == 'hyperv'
| project Computer, VirtualMachineType
"@

$vmlogs = Invoke-AzOperationalInsightsQuery -WorkspaceId '6ec488ea-8ef2-45a8-8892-9f8ed30b8de9' -Query $vmquery 
Write-Output $vmlogs

# Display the results
$vmresults  

#Get-AzOperationalInsightsDataExport -ResourceGroupName "defaultresourcegroup-eus"  -WorkspaceName DefaultWorkspace-5755893a-8056-4ba8-9916-1133c80a80f3-EUS -DataExportName "DefaultWorkspace-5755893a-8056-4ba8-9916-1133c80a80f3-EUS_diags"
 
 Get-AzOperationalInsightsWorkspace

Get-AzOperationalInsightsDataSource -Kind CustomLog -ResourceGroupName "defaultresourcegroup-eus" -WorkspaceName LogAnalyticsWorkspace

$arcServers = Get-AzConnectedMachine

try {
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "defaultresourcegroup-eus" -Name "DefaultWorkspace-5755893a-8056-4ba8-9916-1133c80a80f3-EUS"
    if ($null -eq $workspace) {
        throw "Workspace not found"
    }

    $logs = Get-AzOperationalInsightsSearchResults -WorkspaceId $workspace.ResourceId -Query "Heartbeat | where TimeGenerated > ago(1h) | project Computer, ProcessName"
    Write-Output $logs

} catch {
    Write-Error "An error occurred: $_"
}

foreach ($log in $logs) {
    $processes = Get-AzOperationalInsightsSearchResults -WorkspaceId $log.ResourceId -Query "Heartbeat | where TimeGenerated > ago(3d) | project Computer, ProcessName"
    Write-Output $processes
}


# Define the query
$query = @"
Heartbeat
| project Computer, OSType, OSName, IPAddress, TimeGenerated
| summarize by Computer, OSType, OSName, IPAddress
"@

# Run the query
$workspaceId = '6ec488ea-8ef2-45a8-8892-9f8ed30b8de9'
$results = Invoke-AzOperationalInsightsQuery -Workspace   -Query $query

# Display the results
$results.Results