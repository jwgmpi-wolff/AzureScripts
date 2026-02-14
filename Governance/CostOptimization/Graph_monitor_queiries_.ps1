# Connect to your cloud service account
Connect-AzAccount -identity

# Define the query to find resources with potential cost issues
$query = @"
resources
| where type == "microsoft.hybridcompute/machines"
"@

# Run the query
$results = Search-AzGraph -Query $query

# Display the results
$results | Format-Table -Property name, status

Get-AzOperationalInsightsDataExport -ResourceGroupName "defaultresourcegroup-eus"  -WorkspaceName DefaultWorkspace-5755893a-8056-4ba8-9916-1133c80a80f3-EUS -DataExportName "DefaultWorkspace-5755893a-8056-4ba8-9916-1133c80a80f3-EUS_diags"



 Get-AzOperationalInsightsWorkspace

Get-AzOperationalInsightsDataSource -Kind CustomLog -ResourceGroupName "defaultresourcegroup-eus" -WorkspaceName LogAnalyticsWorkspace

$arcServers = Get-AzConnectedMachine

try {
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "defaultresourcegroup-eus" -Name "wolffmslenovo2"
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

 


