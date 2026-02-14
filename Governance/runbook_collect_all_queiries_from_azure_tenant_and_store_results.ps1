param(
    [Parameter(Mandatory=$true)][string]$StorageAccountName,
    [Parameter(Mandatory=$true)][string]$StorageResourceGroup,
    [Parameter(Mandatory=$true)][string]$StorageContainer,
    [Parameter(Mandatory=$true)][string]$TeamsWebhookUri #,
  #  [Parameter(Mandatory=$false)][string[]]$TargetSubscriptionIds = @()
)

# --- Init / Auth ---
Write-Output "Starting underutilization & query execution runbook..."
Connect-AzAccount -Identity

# Get the Automation managed identity principal id (useful for logging)
try { $mi = (Get-AzContext).Account } catch { $mi = $null }
Write-Output "Connected as: $mi"

# Prepare storage context and ensure container exists
$storage = Get-AzStorageAccount -ResourceGroupName $StorageResourceGroup -Name $StorageAccountName -ErrorAction Stop
$ctx = $storage.Context

# create container if not exists
try {
    $exists = Get-AzStorageContainer -Context $ctx -Name $StorageContainer -ErrorAction SilentlyContinue
    if (-not $exists) {
        Write-Output "Creating container $StorageContainer"
        New-AzStorageContainer -Name $StorageContainer -Context $ctx | Out-Null
    } else {
        Write-Output "Container $StorageContainer exists"
    }
} catch {
    Throw "Failed to access/create storage container: $_"
}

# Timestamp for blob names
$ts = (Get-Date).ToString("yyyyMMdd_HHmmss")

# Resolve subscriptions to operate on
$allSubs = @()
if ($TargetSubscriptionIds -and $TargetSubscriptionIds.Count -gt 0) {
    foreach ($s in $TargetSubscriptionIds) {
        $sub = Get-AzSubscription -SubscriptionId $s -ErrorAction SilentlyContinue
        if (-not $sub) { $sub = Get-AzSubscription -SubscriptionName $s -ErrorAction SilentlyContinue }
        if ($sub) { $allSubs += $sub } else { Write-Warning "Subscription not found: $s" }
    }
} else {
    $allSubs = Get-AzSubscription
}

if (-not $allSubs -or $allSubs.Count -eq 0) { Throw "No subscriptions found/selected." }

# Collections
$savedSearches = @()
$alertRules = @()
$resourceGraphQueries = @()
$queryPackItems = @()

# Iterate subscriptions: discover saved searches, alert rules, resource graph queries and query packs
foreach ($sub in $allSubs) {
    Write-Output "Processing subscription: $($sub.Name) ($($sub.Id))"
    Set-AzContext -Subscription $sub.Id | Out-Null

    # --- Saved Searches (Log Analytics) ---
    try {
        $workspaces = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
        foreach ($ws in $workspaces) {
            Write-Output "  Workspace: $($ws.Name) in RG $($ws.ResourceGroupName)"
            try {
                $logsearches = Get-AzOperationalInsightsSavedSearch -ResourceGroupName $ws.ResourceGroupName -WorkspaceName $ws.Name -ErrorAction SilentlyContinue
            } catch { $logsearches = @() }
            foreach ($ls in $logsearches) {
                # SavedSearch returns .Properties or .value shape depending - normalize:
                if ($ls.value) {
                    foreach ($v in $ls.value) {
                        $obj = [pscustomobject]@{
                            SubscriptionId   = $sub.Id
                            SubscriptionName = $sub.Name
                            ResourceGroup    = $ws.ResourceGroupName
                            WorkspaceName    = $ws.Name
                            WorkspaceId      = $ws.CustomerId
                            SavedSearchId    = ($v.Id -split "/")[-1]
                            DisplayName      = $v.name
                            Category         = $v.type
                            Query            = ($v.properties.query -join "`n")
                            Source           = "SavedSearch"
                        }
                        $savedSearches += $obj
                    }
                } else {
                    # older shape
                    $obj = [pscustomobject]@{
                        SubscriptionId   = $sub.Id
                        SubscriptionName = $sub.Name
                        ResourceGroup    = $ws.ResourceGroupName
                        WorkspaceName    = $ws.Name
                        WorkspaceId      = $ws.CustomerId
                        SavedSearchId    = $ls.Name
                        DisplayName      = $ls.DisplayName
                        Category         = $ls.Category
                        Query            = $ls.Query
                        Source           = "SavedSearch"
                    }
                    $savedSearches += $obj
                }
            }
        }
    } catch {
        Write-Warning "Failed to enumerate saved searches in subscription $($sub.Name): $_"
    }

    # --- Scheduled Query Rules (Log Alerts) ---
    try {
        $rgs = Get-AzResourceGroup -ErrorAction SilentlyContinue
        foreach ($rg in $rgs) {
            try { $rules = Get-AzScheduledQueryRule -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop } catch { $rules = @() }
            foreach ($r in $rules) {
                # r.CriterionAllOf may be an array or object - attempt to extract query parts
                $q = ""
                if ($r.CriterionAllOf -ne $null) {
                    if ($r.CriterionAllOf.query) { $q = $r.CriterionAllOf.query } else {
                        # some shapes store criterion in nested arrays
                        try {
                            $q = ($r.CriterionAllOf | ForEach-Object { $_.query } | Where-Object { $_ -ne $null } | Select-Object -First 1)
                        } catch { $q = "" }
                    }
                }
                $obj = [pscustomobject]@{
                    SubscriptionId   = $sub.Id
                    SubscriptionName = $sub.Name
                    ResourceGroup    = $rg.ResourceGroupName
                    RuleName         = $r.Name
                    Location         = $r.Location
                    Enabled          = $r.Enabled
                    Severity         = $r.Severity
                    Scope            = ($r.Scope -join ",")
                    ActionGroups     = ($r.ActionGroup -join ",")
                    Queries          = $q
                    Source           = "ScheduledQueryRule"
                }
                $alertRules += $obj
            }
        }
    } catch {
        Write-Warning "Failed to enumerate scheduled query rules in subscription $($sub.Name): $_"
    }

    # --- Resource Graph queries (stored as resources) ---
    try {
        # resource type for saved ARG queries
        $rgQueries = Get-AzResource -ResourceType "microsoft.resourcegraph/queries" -ErrorAction SilentlyContinue
        foreach ($rq in $rgQueries) {
            $qbody = ""
            try {
                if ($rq.Properties) { $qbody = $rq.Properties.query } elseif ($rq.Properties -and $rq.Properties.query) { $qbody = $rq.Properties.query }
            } catch { $qbody = $null }
            $obj = [pscustomobject]@{
                SubscriptionId   = $sub.Id
                SubscriptionName = $sub.Name
                ResourceGroup    = $rq.ResourceGroupName
                Name             = $rq.Name
                Kql              = $qbody
                Source           = "ResourceGraph"
            }
            $resourceGraphQueries += $obj
        }
    } catch {
        Write-Warning "Failed to enumerate resource graph queries: $_"
    }

    # --- Query Packs (OperationalInsights/queryPacks) - read pack items via REST if present ---
    try {
        $qpList = Get-AzResource -ResourceType "Microsoft.OperationalInsights/queryPacks" -ErrorAction SilentlyContinue
        foreach ($qp in $qpList) {
            Write-Output "  Found QueryPack: $($qp.Name) (RG: $($qp.ResourceGroupName))"
            $apiVersion = "2025-07-01"
            try {
                $resp = Invoke-AzRestMethod -Method GET -Path "$($qp.ResourceId)/queries?api-version=$apiVersion" -ErrorAction Stop
                $content = $resp.Content | ConvertFrom-Json
                $items = @()
                if ($content.value) { $items = $content.value } elseif ($content.properties) { $items = @($content) }
                foreach ($item in $items) {
                    $p = $item.properties
                    $obj = [pscustomobject]@{
                        SubscriptionId   = $sub.Id
                        SubscriptionName = $sub.Name
                        ResourceGroup    = $qp.ResourceGroupName
                        QueryPackName    = $qp.Name
                        QueryId          = $item.name
                        DisplayName      = $p.displayName
                        Description      = $p.description
                        ResourceTypes    = ($p.related.resourceTypes -join ", ")
                        QueryBody        = $p.body
                        Source           = "QueryPack"
                    }
                    $queryPackItems += $obj
                }
            } catch {
                Write-Warning "    Could not fetch queries for pack $($qp.Name): $_"
            }
        }
    } catch {
        Write-Warning "Failed to enumerate query packs: $_"
    }
}

# Persist a consolidated index (JSON) to blob for auditing
$indexObj = [pscustomobject]@{
    CollectedAt = (Get-Date).ToString("o")
    SavedSearchesCount = $savedSearches.Count
    AlertRulesCount = $alertRules.Count
    ResourceGraphCount = $resourceGraphQueries.Count
    QueryPackItemsCount = $queryPackItems.Count
    Subscriptions = $allSubs | Select Name, Id
}
$indexJson = $indexObj | ConvertTo-Json -Depth 6
$indexBlob = "query_index_$ts.json"
Set-AzStorageBlobContent -File ([System.IO.Path]::GetTempFileName()) -Container $StorageContainer -Blob $indexBlob -Context $ctx -Force | Out-Null
# Overwrite actual content properly:
$indexTemp = Join-Path $env:TEMP ("index_$ts.json")
$indexJson | Out-File -FilePath $indexTemp -Encoding utf8
Set-AzStorageBlobContent -File $indexTemp -Container $StorageContainer -Blob $indexBlob -Context $ctx -Force | Out-Null
Write-Output "Wrote index blob: $indexBlob"

# Helper: run Log Analytics KQL and upload CSV
function Run-LogAnalyticsQueryAndUpload {
    param($workspaceId, $kql, $label)

    if ([string]::IsNullOrWhiteSpace($kql)) { Write-Warning "Empty KQL for $label"; return $null }
    try {
        Write-Output "Running Log Analytics query for $label (workspace: $workspaceId)..."
        $res = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $kql -ErrorAction Stop
        if ($res.Results -and $res.Results.Count -gt 0) {
            $tmp = Join-Path $env:TEMP ("$label-$ts.csv")
            $res.Results | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $tmp -Encoding utf8
            $blobName = ("{0}-{1}.csv" -f ($label -replace '[^0-9A-Za-z\-]','_'), $ts)
            Set-AzStorageBlobContent -File $tmp -Container $StorageContainer -Blob $blobName -Context $ctx -Force | Out-Null
            Write-Output "Uploaded blob: $blobName"
            return @{ Label = $label; Blob = $blobName; Rows = $res.Results.Count }
        } else {
            Write-Output "No rows returned for $label"
            return @{ Label=$label; Blob=""; Rows=0 }
        }
    } catch {
        Write-Warning "Failed to run Log Analytics query for $label : $_"
        return @{ Label=$label; Blob=""; Rows=0; Error = $_.ToString() }
    }
}

# Helper: run Resource Graph KQL and upload CSV
function Run-ResourceGraphQueryAndUpload {
    param($kql, $label)
    if ([string]::IsNullOrWhiteSpace($kql)) { Write-Warning "Empty ARG KQL for $label"; return $null }
    try {
        Write-Output "Running Resource Graph query for $label..."
        $rgRes = Search-AzGraph -Query $kql -First 10000 -ErrorAction Stop
        if ($rgRes -and $rgRes.Count -gt 0) {
            $tmp = Join-Path $env:TEMP ("rg-$label-$ts.csv")
            $rgRes | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $tmp -Encoding utf8
            $blobName = ("rg-{0}-{1}.csv" -f ($label -replace '[^0-9A-Za-z\-]','_'), $ts)
            Set-AzStorageBlobContent -File $tmp -Container $StorageContainer -Blob $blobName -Context $ctx -Force | Out-Null
            Write-Output "Uploaded ARG blob: $blobName"
            return @{ Label=$label; Blob=$blobName; Rows=$rgRes.Count }
        } else {
            Write-Output "No rows returned for ARG query $label"
            return @{ Label=$label; Blob=""; Rows=0 }
        }
    } catch {
        Write-Warning "Failed to run ARG query $label : $_"
        return @{ Label=$label; Blob=""; Rows=0; Error=$_.ToString() }
    }
}

# Execute Saved Searches (per workspace)
$executionSummary = @()
foreach ($ss in $savedSearches) {
    $label = "SavedSearch_$($ss.DisplayName -replace '\s+','_')"
    $wsId = $ss.WorkspaceId
    $kql = $ss.Query
    $out = Run-LogAnalyticsQueryAndUpload -workspaceId $wsId -kql $kql -label $label
    if ($out) { $executionSummary += $out }
}

# Execute Alert rule queries (if they contain a KQL and we can locate workspace)
foreach ($ar in $alertRules) {
    if ($ar.Queries -and $ar.Queries.Trim().Length -gt 0) {
        # Attempt to guess workspace: check subscription's workspaces and run against each (safer) or allow fallback by providing a default workspace
        # We'll attempt against every workspace in the owning subscription (may be noisy); you can change logic to map rules to a workspace.
        $workspaces = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
        foreach ($ws in $workspaces) {
            $label = "AlertRule_$($ar.RuleName -replace '\s+','_')_WS_$($ws.Name)"
            $out = Run-LogAnalyticsQueryAndUpload -workspaceId $ws.CustomerId -kql $ar.Queries -label $label
            if ($out) { $executionSummary += $out }
        }
    }
}

# Execute Resource Graph queries
foreach ($rgq in $resourceGraphQueries) {
    $label = "RGQuery_$($rgq.Name -replace '[^0-9A-Za-z\-]','_')"
    $kql = $rgq.Kql
    $out = Run-ResourceGraphQueryAndUpload -kql $kql -label $label
    if ($out) { $executionSummary += $out }
}

# Optionally run Query Pack items (they may be Log Analytics KQLs). Attempt to run them against all workspaces as a fallback.
foreach ($item in $queryPackItems) {
    if ($item.QueryBody) {
        $kql = $item.QueryBody
        # run against all workspaces in subscription (can be scoped further)
        $workspaces = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue
        foreach ($ws in $workspaces) {
            $label = ("QP_{0}_{1}" -f ($item.QueryPackName -replace '\s+','_'), ($ws.Name -replace '\s+','_'))
            $out = Run-LogAnalyticsQueryAndUpload -workspaceId $ws.CustomerId -kql $kql -label $label
            if ($out) { $executionSummary += $out }
        }
    }
}

# Summary report and Teams post
$summaryBlobName = "execution_summary_$ts.json"
$summaryJson = $executionSummary | ConvertTo-Json -Depth 6
$summaryTemp = Join-Path $env:TEMP ("summary_$ts.json")
$summaryJson | Out-File -FilePath $summaryTemp -Encoding utf8
Set-AzStorageBlobContent -File $summaryTemp -Container $StorageContainer -Blob $summaryBlobName -Context $ctx -Force | Out-Null

# Post a brief message to Teams
$teamsBody = @{
    text = "agentwolff007 runbook complete. Summary blob: https://$($StorageAccountName).blob.core.windows.net/$($StorageContainer)/$($summaryBlobName)`nTotal queries executed: $($executionSummary.Count)"
} | ConvertTo-Json
try {
    Invoke-RestMethod -Uri $TeamsWebhookUri -Method Post -Body $teamsBody -ContentType "application/json" -ErrorAction Stop
    Write-Output "Posted summary to Teams webhook."
} catch {
    Write-Warning "Failed to post to Teams webhook: $_"
}

Write-Output "Runbook finished. Summary blob: $summaryBlobName"