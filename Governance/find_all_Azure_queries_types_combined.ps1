 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
Connect-AzAccount -identity
# (Optional) Use a specific tenant or subscription:
# Connect-AzAccount -Tenant <TenantId>






$timestamp = (Get-Date).ToString('yyyyMMdd_HHmm')
$savedOutCsv = "c:\temp\savedsearches_$timestamp.csv"
$alertsOutCsv = "c:\temp\logalerts_$timestamp.csv"
$resopurcegraphqueiriesjson  = "c:\temp\resourcegraphqueiries.json"
$alertrulesjson = 'c:\temp\alertsrules.json'


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


$alertrules | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $alertrulesjson -Encoding UTF8

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

 
 
 ########################################

 
 $Subscriptions = Get-AzSubscription  #-SubscriptionName wolffentpsub

 $outputjson = 'c:\temp\consolidatequeries.json'

# Resolve subscriptions
$targetSubs = if ($Subscriptions -and $Subscriptions.Count -gt 0) {
    $Subscriptions | ForEach-Object {
        $sub = Get-AzSubscription -SubscriptionId $_ -ErrorAction SilentlyContinue
        if (-not $sub) { $sub = Get-AzSubscription -SubscriptionName $_ -ErrorAction SilentlyContinue }
        if ($sub) { $sub } else { Write-Warning "Subscription '$_' not found."; $null }
    } | Where-Object { $_ -ne $null }
} else {
    @(Get-AzContext).Subscription
}

if (-not $targetSubs -or $targetSubs.Count -eq 0) {
    throw "No valid subscriptions to search."
}
 
 
 
$results = ''

foreach ($sub in $targetSubs) {
    Write-Host "Searching subscription: $($sub.Name) ($($sub.Id))" -ForegroundColor Cyan
    Set-AzContext -Subscription $sub.Id | Out-Null

 

    # Find Query Packs (resource type: Microsoft.OperationalInsights/queryPacks)
    $queryPacks = Get-AzResource -ResourceType "Microsoft.OperationalInsights/queryPacks" -ErrorAction SilentlyContinue

    if ($ResourceGroups -and $ResourceGroups.Count -gt 0) {
        $queryPacks = $queryPacks | Where-Object { $ResourceGroups -contains $_.ResourceGroupName }
    }

    foreach ($qp in $queryPacks) {
        Write-Host "  Query Pack: $($qp.Name)  RG: $($qp.ResourceGroupName)" -ForegroundColor Yellow

        $apiVersion = "2025-07-01"
        $qp = Get-AzResource -ResourceType "Microsoft.OperationalInsights/queryPacks" -ResourceGroupName "$($qp.resourcegroupname)" -Name "$($qp.name)"
      
        $resp = Invoke-AzRestMethod -Method GET -Path "$($qp.ResourceId)/queries?api-version=$apiVersion" |
          Select -ExpandProperty Content
           $resp 

 
    

        $body = $resp | ConvertFrom-Json
        $items = @()
        if ($body.value) { $items = $body.value } elseif ($body.properties) { $items = @($body) } # safety

        foreach ($item in $items) {
            # ARM shape: id, name, type, properties.{displayName, description, body, related{categories,resourceTypes,solutions}, tags}
            $p = $item.properties

                $resultsobj = new-object psobject

                $resultsobj | add-member -MemberType NoteProperty -name   SubscriptionId    -value  $sub.Id 
                $resultsobj | add-member -MemberType NoteProperty -name    SubscriptionName  -value  $sub.Name
                $resultsobj | add-member -MemberType NoteProperty -name  ResourceGroup     -value  $qp.ResourceGroupName
                $resultsobj | add-member -MemberType NoteProperty -name  QueryPackName     -value  $qp.Name
                $resultsobj | add-member -MemberType NoteProperty -name  QueryId           -value  $item.name
                $resultsobj | add-member -MemberType NoteProperty -name  DisplayName       -value  $p.displayName
                $resultsobj | add-member -MemberType NoteProperty -name   Description       -value  $p.description 
                $resultsobj | add-member -MemberType NoteProperty -name  Categories        -value  ($p.related.categories -join ", ")
                $resultsobj | add-member -MemberType NoteProperty -name  ResourceTypes     -value  ($p.related.resourceTypes -join ", ")
                $resultsobj | add-member -MemberType NoteProperty -name  Solutions         -value  ($p.related.solutions -join ", ")
  
                $resultsobj | add-member -MemberType NoteProperty -name QueryBody         -value  $p.body
 
 
               [array]$results += $resultsobj  
            
        }
    }
}


$results


if ($OutputJson) {
    $results | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputJson -Encoding UTF8
    Write-Host "Wrote matched queries to: $OutputJson" -ForegroundColor Green
}

# Present concise table
$results |
    Select-Object SubscriptionId, SubscriptionName, ResourceGroup, QueryPackName, QueryId, DisplayName, Description, Categories, ResourceTypes, Solutions ,Querybody |
    Sort-Object SubscriptionName, ResourceGroup, QueryPackName, DisplayName |
    export-Csv c:\temp\azure_querypack_queries.csv -NoTypeInformation

Write-Host "`nTotal matches: $($results.Count)`n"
