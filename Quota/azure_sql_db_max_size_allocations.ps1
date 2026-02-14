<#

.NOTES

    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 

    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 

    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 

    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all

    implied warranties including, without limitation, any implied warranties of merchantability

    or of fitness for a particular purpose. The entire risk arising out of the use or performance

    of the sample and documentation remains with you. In no event shall Microsoft, its authors,

    or anyone else involved in the creation, production, or delivery of the script be liable for 

    any damages whatsoever (including, without limitation, damages for loss of business profits, 

    business interruption, loss of business information, or other pecuniary loss) arising out of 

    the use of or inability to use the sample or documentation, even if Microsoft has been advised 

    of the possibility of such damages, rising out of the use of or inability to use the sample script, 

    even if Microsoft has been advised of the possibility of such damages.

    Script Name: update_allowed_sku_policy_and_assignment_from_master_in_storage_regional.ps1

    Description: 

     

Here’s a summary of the process flow for the provided script:

Connect to Azure Account:
    The script starts by connecting to your Azure account using Connect-AzAccount -identity.
    Select Subscriptions:
    It retrieves a list of subscriptions and allows you to select the ones you want to check using 
    Get-AzSubscription and Out-GridView.
    Set Context for Each Subscription:
    For each selected subscription, the script sets the context using Set-AzContext.
    Retrieve Resource Groups:
    It retrieves all resource groups within the current subscription using Get-AzResourceGroup.
    Get SQL Servers:
    For each resource group, the script retrieves a list of SQL servers using Get-AzSqlServer.
    Loop Through SQL Servers:
    For each SQL server, it outputs the server name, resource group, and location.
    Get SQL Databases:
    It retrieves a list of databases for each SQL server using Get-AzSqlDatabase.
    Output Database Information:
    For each database, it outputs details such as database name, max size, current size, edition, and service level objective.
    Retrieve and Process Usage Data:
    The script uses Azure CLI to get usage data for each database and converts the JSON output to a PowerShell object.
    Create and Populate Quota Object:
    It creates a new PowerShell object for each database to store quota information, including server 
    name, resource group, location, database name, max size, current usage, limit, edition, and service level objective.
    Generate HTML Report:
    The script generates an HTML report of the SQL database usage and limits using ConvertTo-Html and saves it to a file.
    Open HTML Report:
    Finally, it opens the generated HTML report using Invoke-Item.
    This process ensures that you get a detailed report of your Azure SQL Database usage and limits across 
    multiple subscriptions and resource groups.


#>
$env:AZURE_CLIENTS_SHOW_SECRETS_WARNING = "false"
# Connect to your Azure account
Connect-AzAccount -identity

 
 $sqlquotausage = ''

$subscriptions = get-azsubscription  | ogv -title " Select a Subscriptions to check : " -PassThru | select name, id



foreach($sub in $subscriptions)
{
set-azcontext -Subscription $($sub.name)

    $rgs = get-azresourcegroup 
    foreach($rg in $rgs)
    {
        # Get list of SQL servers in the subscription
        $sqlServers = Get-AzSqlServer -ResourceGroupName $($rg.resourcegroupname)

 

                # Loop through each server to get database quotas
                foreach ($server in $sqlServers) {
                    Write-Output "Server Name: $($server.ServerName)"
                Write-Output "Resource Group: $($server.ResourceGroupName)"
                Write-Output "Location: $($server.Location)"
                Write-Output "-----------------------------"

                $databases = Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName
                foreach ($db in $databases) {
                    Write-Output "  Database: $($db.DatabaseName)"
                    Write-Output "  Max Size: $($db.MaxSizeBytes / 1GB) GB"
                    Write-Output "  Current Size: $($db.CurrentSizeBytes / 1GB) GB"
                    Write-Output "  Edition: $($db.Edition)"
                    Write-Output "  Service Level Objective: $($db.ServiceLevelObjective)"
                    Write-Output "  -----------------------------"
               


                $resourceGroupName = $($server.ResourceGroupName)
                $sqlusage = az sql db list-usages --resource-group "$resourceGroupName" --server $($server.servername) --name $($db.databaseName)
                $sqlusagedata = $sqlusage |convertfrom-json 
                 $sqlusagedata
                    
                foreach($sqldbusage in $sqlusagedata)
                    {

                $quotaobj = new-object PSObject 


                $quotaobj | add-member -MemberType NoteProperty -Name SQlServername -Value $($server.ServerName)
                $quotaobj | add-member -MemberType NoteProperty -Name Resourcegroup -Value $($server.ResourceGroupName)
                $quotaobj | add-member -MemberType NoteProperty -Name Location -Value $($server.Location)
                $quotaobj | add-member -MemberType NoteProperty -Name Databasename -Value $($db.DatabaseName)
                $quotaobj | add-member -MemberType NoteProperty -Name MAxSize -Value "$($db.MaxSizeBytes / 1GB) GB"
                $quotaobj | add-member -MemberType NoteProperty -Name CurrentUsage -Value "$($sqldbusage.currentvalue) / 1GB) GB"
                $quotaobj | add-member -MemberType NoteProperty -Name limit -Value "$($sqldbusage.limit) / 1GB) GB"
                $quotaobj | add-member -MemberType NoteProperty -Name Edition -Value "$($db.Edition)"
                $quotaobj | add-member -MemberType NoteProperty -Name serviceLevelObjective -Value "$($db.ServiceLevelObjective)"

 

               [array]$sqlquotausage += $quotaobj
                }
            }

         }
      }

 }

$CSS = @"

<Title>Azure SQl Db usage and limits : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure SQl Db usage and limits : $(Get-Date -Format 'dd MMMM yyyy')  </H2>

<Style>


th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	border-top: 1px solid #C1DAD7;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #6D929B;
}
</Style>


"@




($sqlquotausage | select SQlServername ,Resourcegroup,Location,Databasename, MAxSize, CurrentUsage, limit,Edition  ,serviceLevelObjective `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\sqldbusagelimits.html"


invoke-item "c:\temp\sqldbusagelimits.html"











































