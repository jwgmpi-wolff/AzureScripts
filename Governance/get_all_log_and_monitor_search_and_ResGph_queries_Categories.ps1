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
 
 
.SYNOPSIS
Export Azure Log Analytics Saved Searches and Scheduled Query (Log Alert) rules
across all accessible subscriptions to timestamped CSV files.

.DESCRIPTION
This script authenticates to Azure (Managed Identity by default) and iterates through
each subscription the caller can access. For every Log Analytics workspace it finds,
it exports Saved Searches (queries) to a CSV. It also enumerates Scheduled Query Rules
(Log Alerts) in every resource group, capturing key configuration fields to a second CSV.

Two output files are created under C:\Temp by default (configurable in the variables):
    - savedsearches_<yyyyMMdd_HHmm>.csv
    - logalerts_<yyyyMMdd_HHmm>.csv

To reduce console noise from Az module “breaking change” notices during rule enumeration,
the script sets the environment variable:
    Env:\SuppressAzurePowerShellBreakingChangeWarnings = $true
(You can remove or change this behavior based on your governance standards.)

.REQUIREMENTS
- PowerShell 7.x or Windows PowerShell 5.1
- Az PowerShell modules:
    Az.Accounts, Az.OperationalInsights, Az.Monitor, Az.Resources
  Install (for the current user):
    Install-Module Az -Scope CurrentUser
- Permissions:
    Reader (or above) on target subscriptions and resource groups.
    Log Analytics Reader for retrieving workspace saved searches.
    Monitor Reader for retrieving Scheduled Query Rules.
- Authentication:
    - Default: Connect-AzAccount -Identity (Managed Identity context)
    - Optional: Connect-AzAccount -Tenant <TenantId> (service principal / user)
      Ensure the identity has the required rights listed above.

.PARAMETERS
None (current implementation uses built-in defaults and iterates all subscriptions).
You can adapt `$savedOutCsv`, `$alertsOutCsv`, or scope to specific subscription IDs
or resource groups if required.

.OUTPUTS
CSV files containing:
- Saved Searches:
    SubscriptionId, SubscriptionName, ResourceGroup, WorkspaceName, WorkspaceId,
    SavedSearchId, DisplayName, Category, Query
- Log Alerts:
    SubscriptionName, ResourceGroup, RuleName, Location, Enabled, Severity, Scope,
    ActionGroups, Queries, MetricMeasureColumn

 **Azure Resource Graph saved query extraction**
- Export to **JSON** (full fidelity including KQL body)
- Export to **CSV** (tabular reporting: Name, Location, Type, ResourceGroupName, Id, Kql)


.FLOW
1) Authenticate
   - Connect-AzAccount -Identity
   - (Optional) Connect-AzAccount -Tenant <TenantId>

2) Initialize runtime and output paths
   - Timestamp → yyyyMMdd_HHmm
   - C:\Temp\savedsearches_<ts>.csv
   - C:\Temp\logalerts_<ts>.csv

3) Enumerate Subscriptions
   - Get-AzSubscription
   - For each subscription:
       a) Set-AzContext -Subscription <Id>

       b) Saved Searches
          - Get-AzOperationalInsightsWorkspace
          - For each workspace:
              • Get-AzOperationalInsightsSavedSearch
              • Project properties into PSObjects
              • Accumulate → $savedsearches

       c) Log Alerts
          - Get-AzResourceGroup
          - For each RG:
              • Get-AzScheduledQueryRule
              • Project properties into PSObjects
              • Accumulate → $alertrules

4) Export
   - Export-Csv savedsearches → $savedOutCsv
   - Export-Csv logalerts     → $alertsOutCsv

5) Finish
   - Write-Host summary with output locations

.OPERATIONAL NOTES
- Warning Suppression:
  The script uses `Env:\SuppressAzurePowerShellBreakingChangeWarnings = $true` only for
  the Log Alerts section to keep the console clean. Prefer using `Update-AzConfig`
  for centrally managed settings if your environment requires strict configuration tracking.

- Error Handling:
  - Saved searches use `-ErrorAction SilentlyContinue` to keep enumeration resilient when
    a workspace returns no saved searches.
  - Scheduled Query Rules wrap `Get-AzScheduledQueryRule` in try/catch to prevent RG-level
    failures from halting enumeration.

- Performance:
  In large estates, this may take time. Consider scoping by subscription or RG,
  and running in parallel (e.g., `ForEach-Object -Parallel` in PowerShell 7)
  if permitted by your operational standards.

- Security:
  Output CSVs may contain queries and alert metadata. Store and share according to
  your organization’s data handling policies. Do not include secrets in saved searches.

.KNOWN LIMITATIONS
- SavedSearchId and DisplayName parsing can vary by API shape/version; confirm field paths
  if you see blanks. Some properties arrive nested (e.g., `.Value` collections).
- `$SUB` is referenced for SubscriptionName; ensure it is scoped and spelled consistently
  within its loop.
- `$alertrules` must be initialized (e.g., `$alertrules = @()`) before accumulation.
- Final Write-Host references “Saved Searches CSV” but prints `$alertsOutCsv`; adjust message.

.TROUBLESHOOTING
- Access errors: Verify identity permissions (Reader/Log Analytics Reader/Monitor Reader).
- Empty outputs: Confirm there are workspaces and scheduled query rules in target subscriptions.
- Warning messages still appear: Use `Update-AzConfig -DisplayBreakingChangeWarning $false`
  or remove the environment variable line if your compliance forbids runtime suppression.

.EXAMPLE
# Managed Identity (e.g., Azure Automation / Function App with system-assigned identity)
Connect-AzAccount -Identity
# Optionally restrict to a single subscription:
# Set-AzContext -Subscription "<SUBSCRIPTION-ID>"

# Run the script; outputs will be placed in C:\Temp with a timestamped suffix.
#>


#>
# Requires the Az PowerShell modules:
# Az.Accounts, Az.OperationalInsights, Az.Monitor, Az.Resources
# Install if needed:
# Install-Module Az -Scope CurrentUser

Connect-AzAccount -identity
# (Optional) Use a specific tenant or subscription:
# Connect-AzAccount -Tenant <TenantId>






$timestamp = (Get-Date).ToString('yyyyMMdd_HHmm')
$savedOutCsv = "c:\temp\savedsearches_$timestamp.csv"
$alertsOutCsv = "c:\temp\logalerts_$timestamp.csv"
$resopurcegraphqueiriesjson  = "c:\temp\resourcegraphqueiries.json"

# --- Saved Searches ---
$savedsearches = ''
$subs = Get-AzSubscription  

foreach ($sub in $subs)
{
    Set-AzContext -Subscription $sub.Id | Out-Null
   $workspaces =  Get-AzOperationalInsightsWorkspace 
    ForEach ($ws in $workspaces)
    {
       
       $logsearches =  Get-AzOperationalInsightsSavedSearch -ResourceGroupName $ws.ResourceGroupName -WorkspaceName $ws.Name -ErrorAction SilentlyContinue 
        
      }  
        foreach($logsearch in $logsearches) 
        {
            foreach($logsearchvalue in $logsearch.value)
            {
            $logsearchvalue 
        $logsrchobj = new-object PSObject 

  
           
            $logsrchobj | add-member -membertype noteproperty -name      SubscriptionId    -value  "($ws.resourceid -split '/')[2]"
             $logsrchobj | add-member -membertype noteproperty -name     SubscriptionName  -value  "$($SUB.name)"
             $logsrchobj | add-member -membertype noteproperty -name     ResourceGroup     -value  "$($ws.ResourceGroupName)"
             $logsrchobj | add-member -membertype noteproperty -name     WorkspaceName     -value  "$($ws.Name)"
             $logsrchobj | add-member -membertype noteproperty -name     WorkspaceId       -value  "$($ws.CustomerId)"
             $logsrchobj | add-member -membertype noteproperty -name     SavedSearchId     -value  "$($logsearchvalueId)"
             $logsrchobj | add-member -membertype noteproperty -name     DisplayName       -value  ($($logsearchvalue.name) -split '_')[01]
              $logsrchobj | add-member -membertype noteproperty -name    Category          -value  "$($logsearchvalue.type)"
             $logsrchobj | add-member -membertype noteproperty -name     Query             -value  "$($logsearchvalue.properties.query)"
              $logsrchobj | add-member -membertype noteproperty -name     querytype             -value  "LogAnalytics"
              
            [array]$savedsearches += $logsrchobj
        }
    }
}

$savedsearches | select SubscriptionId,`
SubscriptionName,`
ResourceGroup,`
WorkspaceName,`
WorkspaceId,`
SavedSearchId,`
DisplayName,`
Category,`
Query | Export-Csv  -Path $savedOutCsv -NoTypeInformation

# --- Scheduled Query Rules (Log Alerts) ---
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

foreach ($sub in $subs)
{
    Set-AzContext -Subscription $sub.Id | Out-Null
$alertRows = @()
 
 
    Get-AzResourceGroup | ForEach-Object {
        $rg = $_
        try { $rules = Get-AzScheduledQueryRule -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop } catch { $rules = @() }
        foreach ($r in $rules) {

            $r.CriterionAllOf


 $alertobj = new-object PSObject 

  
           
            $alertobj | add-member -membertype noteproperty -name      SubscriptionId    -value  "$($sub.Id)"
             $alertobj | add-member -membertype noteproperty -name     SubscriptionName  -value  "$($SUB.name)"
             $alertobj | add-member -membertype noteproperty -name     ResourceGroup     -value  "$($rg.ResourceGroupName)"
             $alertobj | add-member -membertype noteproperty -name     RuleName     -value  "$($r.Name)"
             $alertobj | add-member -membertype noteproperty -name     Location       -value  "$($r.location)"
             $alertobj | add-member -membertype noteproperty -name     Enabled     -value  "$($r.Enabled)"
             $alertobj | add-member -membertype noteproperty -name     Severity       -value  "$($r.Severity)"
             $alertobj | add-member -membertype noteproperty -name     Scope          -value  "$($r.scope)"
             $alertobj | add-member -membertype noteproperty -name     ActionGroups   -value  "$($r.ActionGroup)"
             $alertobj | add-member -membertype noteproperty -name     Queries             -value  "$($r.CriterionAllOf.query)"
             $alertobj | add-member -membertype noteproperty -name     MetricMeasureColumn             -value  "$($r.CriterionAllOf.MetricMeasureColumn)"
              $alertobj | add-member -membertype noteproperty -name     querytype             -value  "Monitor"
               
            [array]$alertrules += $alertobj

 
        }
    }
}
$alertrules | select  SubscriptionName,`
ResourceGroup,`
RuleName,`
Location,`
Enabled,`
Severity,`
Scope,`
ActionGroups,`
Queries,`
MetricMeasureColumn | Export-Csv -NoTypeInformation -Path $alertsOutCsv

Write-Host "Done:"
Write-Host "Saved Searches CSV : $alertsOutCsv"



################################################################

 

$allQueries = @()

# Enumerate every subscription in the tenant
$subs = Get-AzSubscription
foreach ($sub in $subs) {
    $null = Set-AzContext -Subscription $sub.Id

    # Enumerate every RG in the subscription
    $rgs = Get-AzResourceGroup
    foreach ($rg in $rgs) {
        $qs = Get-AzResourceGraphQuery -ResourceGroupName $rg.ResourceGroupName -SubscriptionId $sub.Id
        if ($qs) { $allQueries += $qs }
    }
}

# Display as a table
$allQueries | Select-Object Name, Location, Type, ResourceGroupName, Id | Format-Table -AutoSize

# Optional: export
 

$allQueries | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resopurcegraphqueiriesjson -Encoding UTF8
 

$allQueries |
    Select-Object Name, Location, Type, ResourceGroupName, Id,
        @{Name='Kql'; Expression={$_.Query}} , @{Name='category'; Expression={"resourcegraphquery"}} |
    Export-Csv -Path "c:\temp\ResourceGraphQueries.csv" -NoTypeInformation -Encoding UTF8
 

 ##############################################

 ## Consolidate queries
  

# Paths
$OutDir  = 'C:\temp'
$OutFile = Join-Path $OutDir 'consolidated_queries.csv'

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# --- Normalize each source to the common schema: Name, Kql, Category, Source ---

# 1) Resource Graph queries (from $allQueries): Name, Query -> Kql
$rgRows = $allQueries | Select-Object `
    @{Name='Name';     Expression={$_.Name}},
    @{Name='Kql';      Expression={$_.Query}},
    @{Name='Category'; Expression={'resourcegraphquery'}},
    @{Name='Source';   Expression={'ResourceGraph'}}

# 2) Saved searches (from $savedsearches): DisplayName, Query -> Kql, Category passthrough
$savedRows = $savedsearches | Select-Object `
    @{Name='Name';     Expression={$_.DisplayName}},
    @{Name='Kql';      Expression={$_.Query}},
    @{Name='Category'; Expression={$_.Category}},
    @{Name='Source';   Expression={'SavedSearch'}}

# 3) Alert rules (from $alertrules): map RuleName -> Name, Queries/MetricMeasureColumn -> Kql
#    Category is unified as 'alertrule' (keeps schema comparable); add Source for traceability
$alertRows = $alertrules | Select-Object `
    @{Name='Name';     Expression={$_.RuleName}},
    @{Name='Kql';      Expression={ if ($_.Queries) { $_.Queries } elseif ($_.MetricMeasureColumn) { $_.MetricMeasureColumn } else { '' } }},
    @{Name='Category'; Expression={'alertrule'}},
    @{Name='Source';   Expression={'AlertRules'}}

# Combine
$combined = @()
$combined += $rgRows
$combined += $savedRows
$combined += $alertRows

# De-duplicate (by Name+Kql+Category+Source)
$combined = $combined | Sort-Object Name, Kql, Category, Source -Unique

# Export once (avoids header duplication)
$combined | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8

Write-Host "Consolidated CSV: $OutFile"
