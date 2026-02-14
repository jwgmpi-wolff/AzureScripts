#### Get the current date and time
$currentDate = Get-Date

# Format the date as '2024-11-01T00:00:00Z'
$formattedDate = $currentDate.ToString("yyyy-MM-ddTHH:mm:ssZ")

$Params = @{
  Name = 'test2export'
  DefinitionType = 'ActualCost'
  Scope = "subscriptions/5755893a-8056-4ba8-9916-1133c80a80f3"
  DestinationResourceId = '/subscriptions/5755893a-8056-4ba8-9916-1133c80a80f3/resourceGroups/wolffautomationrg/providers/Microsoft.Storage/storageAccounts/wolffautosa'
  DestinationContainer = 'wolffcostexport'
  DefinitionTimeframe = 'MonthToDate'
  ScheduleRecurrence = 'Daily'
  RecurrencePeriodFrom = $formattedDate
  RecurrencePeriodTo = '2024-12-31T00:00:00Z'
  ScheduleStatus = 'Active'
  DestinationRootFolderPath = 'costexport'
  Format = 'Csv'
  DataSetGranularity = 'Daily'  # Adding the DataSetGranularity parameter
}

New-AzCostManagementExport @Params

#####################
#####################  See details of export 
Get-AzCostManagementExport -Scope 'subscriptions/5755893a-8056-4ba8-9916-1133c80a80f3'

########################  Export to destination 
Update-AzCostManagementExport -Name test2export -Scope 'subscriptions/5755893a-8056-4ba8-9916-1133c80a80f3' -DestinationRootFolderPath demodirectory02 -DataSetGranularity 'Daily'

#########################################################

# Function to create a new out-of-process runspace
function New-OutOfProcRunspace {
    param($ProcessId)
    $ci = New-Object -TypeName System.Management.Automation.Runspaces.NamedPipeConnectionInfo -ArgumentList @($ProcessId)
    $tt = [System.Management.Automation.Runspaces.TypeTable]::LoadDefaultTypeFiles()
    $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($ci, $Host, $tt)
    $Runspace.Open()
    $Runspace
}

# Start a PowerShell 7.4 process
$Process = Start-Process pwsh -ArgumentList @("-NoExit") -PassThru -WindowStyle Hidden

# Push the runspace to the current host
$Runspace = New-OutOfProcRunspace -ProcessId $Process.Id
$Host.PushRunspace($Runspace)

##############
Install-Module -Name FinOpsToolkit -AllowClobber -force
# Import the FinOps toolkit module
update-module FinOpsToolkit -force -verbose
Import-Module FinOpsToolkit 

# Define the export name and scope
$exportName = "test2export"
$scope = "subscriptions/5755893a-8056-4ba8-9916-1133c80a80f3"

# Trigger the export
Start-FinOpsCostExport -Name $exportName -Scope $scope

# Output a confirmation message
Write-Output "Export $exportName has been triggered successfully."


