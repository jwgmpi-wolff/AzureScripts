Connect-azaccount -Identity

##############
# Define the path to pwsh
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"

# Define the script to run in pwsh 7.4.7
$script = {
    Get-Process | Measure-Object
}

# Convert the script block to a string
$scriptString = $script.ToString()

# Run the script in pwsh
Start-Process -FilePath $pwshPath -ArgumentList "-Command", $scriptString -NoNewWindow -Wait


 


##############
import-module Az.CostManagement -Force -verbose
Install-Module -Name FinOpsToolkit -AllowClobber -force
# Import the FinOps toolkit module
update-module FinOpsToolkit -force -verbose
Import-Module FinOpsToolkit -Force -Verbose


####################
$costsub = "wolffentpsub"
# Define the export name and scope
$exportName = "wolffentpsubcostreport"
$scope = "subscriptions/$($costsub.id)"



###############
 
 
$subscription = get-azsubscription -subscriptionname $($costsub.name)

#### Get the current date and time
$currentDate = Get-Date
$reportdate =  $currentDate.ToString("yyyy-MM-dd")
$numberofmonths = 2

 $date = ((Get-Date).AddMonths(-$numberofmonths) )

# Format the date as '2024-11-01T00:00:00Z'
$periodtoDate = $currentDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
$periodfromDate =   $date.ToString("yyyy-MM-ddTHH:mm:ssZ")


$Params = @{
  Name = "$exportName"
  DefinitionType = 'ActualCost'
  Scope = "subscriptions/$($costsub.id)"
  DestinationResourceId = "/subscriptions/$($costsub.id)/resourceGroups/wolffautomationrg/providers/Microsoft.Storage/storageAccounts/wolffautosa"
  DestinationContainer = 'wolffcostexport'
  DefinitionTimeframe = 'MonthToDate'
  ScheduleRecurrence = 'Daily'
  RecurrencePeriodFrom = "$periodfromDate"
  RecurrencePeriodTo = "$periodtoDate"
  ScheduleStatus = 'Active'
  DestinationRootFolderPath = "costexport$reportdate"
  Format = 'Csv'
  DataSetGranularity = 'Daily'  # Adding the DataSetGranularity parameter
}

# Function to create a new out-of-process runspace
function New-OutOfProcRunspace {
    param($ProcessId)
    $ci = New-Object -TypeName System.Management.Automation.Runspaces.NamedPipeConnectionInfo -ArgumentList @($ProcessId)
    $tt = [System.Management.Automation.Runspaces.TypeTable]::LoadDefaultTypeFiles()
    $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($ci, $Host, $tt)
    $Runspace.Open()
    $Runspace
}
 
New-AzCostManagementExport @Params
New-FinOpsCostExport  

#####################
#####################  See details of export 
Get-AzCostManagementExport -Scope "subscriptions/$($costsub.id)"

########################  Export to destination 
Update-AzCostManagementExport -Name test2export -Scope "subscriptions/$($costsub.id)" -DestinationRootFolderPath demodirectory02 -DataSetGranularity 'Daily'

#########################################################
 

# Trigger the export
Start-FinOpsCostExport -Name $exportName -Scope $scope

# Output a confirmation message
Write-Output "Export $exportName has been triggered successfully."


