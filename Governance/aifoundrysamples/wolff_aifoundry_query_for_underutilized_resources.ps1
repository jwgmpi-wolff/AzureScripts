import-module az.monitor

connect-azaccount -Identity
 set-azcontext -Subscription wolffentpsub

$ErrorActionPreference = "silentlycontinue"
 
# Get all workspaces in subscription
$workspaces = Get-AzOperationalInsightsWorkspace



# Define the query to find resources with potential cost issues
$query = @"


// ---- Underutilized resources across common types (30-day lookback) ----
// Adjust thresholds inline as needed

// A) VMs: low CPU (avg < 10%)
let vm_low_cpu =
    AzureMetrics
    | where TimeGenerated >= ago(190d)
    | where MetricName == "Percentage CPU"
    | summarize AvgCPU = avg(Total) by ResourceId
    | where AvgCPU < 10.0
    | project ResourceId, Type = "VirtualMachine", Signal = "LowCPU30d", Detail = strcat("Avg CPU = ", tostring(round(AvgCPU, 2)), " %"), Score = 90;

// B) VMs: low memory used (avg < 20%)
// NOTE: Works only if your workspace emits a memory *percentage* metric in AzureMetrics (name varies by agent/OS).
// Common names include "Memory UsedPercentage" or "Memory Percentage".
// If your workspace uses "Available Memory Bytes" only, skip this section or switch to InsightsMetrics.
let vm_low_mem =
    AzureMetrics
    | where TimeGenerated >= ago(190d)
    | where MetricName in ("Memory UsedPercentage","Memory Percentage")
    | summarize AvgMemUsedPct = avg(Total) by _ResourceId
    | where AvgMemUsedPct < 20.0
    | project _ResourceId, Type = "VirtualMachine", Signal = "LowMem30d", Detail = strcat("Avg Used % = ", tostring(round(AvgMemUsedPct, 2))), Score = 85;

// C) VMs: low disk I/O (avg < 50 ops/sec)
let vm_low_disk =
    AzureMetrics
    | where TimeGenerated >= ago(190d)
    | where MetricName in ("Disk Read Operations/Sec","Disk Write Operations/Sec")
    | summarize AvgIOPS = avg(Total) by ResourceId
    | where AvgIOPS < 50.0
    | project ResourceId, Type = "VirtualMachine", Signal = "LowDiskIO30d", Detail = strcat("Avg IOPS = ", tostring(round(AvgIOPS, 2))), Score = 70;

// D) VMs: low network throughput (avg < 1KB/s)
// (Network metrics are bytes; adjust threshold for your env)
let vm_low_net =
    AzureMetrics
    | where TimeGenerated >= ago(190d)
    | where MetricName in ("Network In Total","Network Out Total")
    | summarize AvgBytesPerSec = avg(Total) by ResourceId
    | where AvgBytesPerSec < 1024.0
    | project ResourceId, Type = "VirtualMachine", Signal = "LowNet30d", Detail = strcat("Avg Net = ", tostring(round(AvgBytesPerSec, 2)), " B/s"), Score = 65;

// E) Storage Accounts: no blob operations in last 30 days
// Requires Storage logging to Log Analytics (StorageBlobLogs)
let storage_no_ops =
    StorageBlobLogs
    | where TimeGenerated >= ago(190d)
    | summarize Ops = count() by _ResourceId
    | where Ops == 0
    | project _ResourceId, Type = "StorageAccount", Signal = "NoBlobOps30d", Detail = "No operations in last 30d", Score = 60;

// F) Public IPs: no NSG flows in last 30 days
// Requires NSG flow logs to Log Analytics (AzureNetworkAnalytics_CL)
let publicip_no_flows =
    AzureNetworkAnalytics_CL
    | where TimeGenerated >= ago(190d)
    | summarize FlowCount = count() by PublicIPs_s
    | where FlowCount == 0
    | project ResourceId = tostring(PublicIPs_s), Type = "PublicIP", Signal = "NoFlows30d", Detail = "No NSG flows in last 30d", Score = 55;

// ---- UNION all signals (tables missing in your workspace are simply empty) ----
vm_low_cpu
| union vm_low_mem
| union vm_low_disk
| union vm_low_net
| union storage_no_ops
| union publicip_no_flows
| order by Score desc, Type asc


"@



$Messageslist = ''



foreach($workspace in $workspaces)
{

# Run the query
$uderutilized = Invoke-AzOperationalInsightsQuery `
    -workspaceid $($Workspace.customerid.guid) `
    -Query $query `
    -Timespan (New-TimeSpan -Days 190)
 
$uderutilized.results

    foreach($resource in $uderutilized.Results)
    {
 

    $resourceobj = new-object PSObject

 
    $resourceobj | add-member -MemberType NoteProperty -Name  ResourceId     -value $($resource.ResourceId)
    $resourceobj | add-member -MemberType NoteProperty -Name  Type     -value $($resource.Type)
    $resourceobj | add-member -MemberType NoteProperty -Name  signal     -value $($resource.signal)
    $resourceobj | add-member -MemberType NoteProperty -Name  Detail    -value $($resource.Detail)
    $resourceobj | add-member -MemberType NoteProperty -Name  Score     -value $($resource.Score)
 
 
 $resourceobj

    [array]$Messageslist += $resourceobj
    }

}
  

 $Messageslist | where resourceid -ne $null  | Select-Object ResourceId,
                  Type,
                  signal,
                  Detail,
                  Score       
 
 
sl "C:\Users\jerrywolff\OneDrive - Microsoft\Documents\azure\PS1"


$aLLRESULTS = ''


foreach($rec in $Messageslist)
{

write-host "$($rec.resourceid)" -foregroundcolor cyan 


$response =  &  .\wolff_ai_foundry_call_HC_noreasoning_cleanonly_poc2.ps1  "provide a recommendation for undertilized resouce $($rec.resourceid) in  $($rec.signal) with $($rec.detail) based on $($rec.type) "  *>&1
   
   
 
# 1) Decode HTML entities so &lt;/think&gt; becomes </think>
Add-Type -AssemblyName System.Web
$decoded = [System.Web.HttpUtility]::HtmlDecode($response )

# 2) Find the first closing </think> tag (case-insensitive), and extract everything after it
$pattern = '</think\s*>'            # allows optional whitespace before '>'
$match   = [System.Text.RegularExpressions.Regex]::Match($decoded, $pattern, 'IgnoreCase')

if ($match.Success) {
    $startIndex = $match.Index + $match.Length
    $afterThink = $decoded.Substring($startIndex)
    
    # 3) Trim leading/trailing whitespace
    $result = $afterThink.Trim()

    # 4) (Optional) Normalize Windows/Mac line endings
    $result = $result -replace "`r?`n", "`r`n"


    $resultobj = new-object PSObject 

   

   $resultobj | add-member -MemberType NoteProperty -name Resourceid -value $($rec.Resourceid)
   $resultobj | add-member -MemberType NoteProperty -name Type -value $($rec.Type)
   $resultobj | add-member -MemberType NoteProperty -name Signal -value $($rec.Signal)
   $resultobj | add-member -MemberType NoteProperty -name Detail -value $($rec.Detail)
   $resultobj | add-member -MemberType NoteProperty -name Score -value $($rec.Score)
   $resultobj | add-member -MemberType NoteProperty -name region -value "$($rec.region)"

   $resultobj | add-member -MemberType NoteProperty -name  RESULTGUIDANCE -value "$($result)"

   [array]$aLLRESULTS += $resultobj


    # Output the extracted portion
    #$result
}

}

##########


  
# --- existing collection logic unchanged up to $aLLRESULTS ---

# Generate HTML report
$date = Get-Date -Format 'dd MMMM yyyy'

$CSS = @"
<title>Azure underutilized report: $date</title>
<style>
table { table-layout: fixed; width: 100%; border-collapse: collapse; }
th {
    font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
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
    font: 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
    border-right: 1px solid #C1DAD7;
    border-bottom: 1px solid #C1DAD7;
    background: #fff;
    padding: 6px 6px 6px 12px;
    color: #333; /* darker for readability */
    vertical-align: top;
}
th:nth-child(1) { width: 30%; }  /* ResourceId */
th:nth-child(2) { width: 10%; }  /* Type */
th:nth-child(3) { width: 10%; }  /* Signal */
th:nth-child(4) { width: 10%; }  /* Detail */
th:nth-child(5) { width: 8%;  }  /* Score */
th:nth-child(6) { width: 32%; }  /* RESULTGUIDANCE */

/* If you keep plain text guidance, preserve its line breaks: */
td:nth-child(6) { 
    white-space: pre-wrap; 
    word-break: break-word; 
}
</style>
"@

# --- Option B: Try converting RESULTGUIDANCE Markdown to HTML ---
$mdAvailable = Get-Command ConvertFrom-Markdown -ErrorAction SilentlyContinue

if ($mdAvailable) {
    # Add an HTML version of guidance to each object
    $aLLRESULTS | ForEach-Object {
        $md = ConvertFrom-Markdown -Markdown $_.RESULTGUIDANCE
        # Wrap in a container to avoid runaway styling and ensure lists look good
        $_ | Add-Member -NotePropertyName RESULTGUIDANCE_HTML -NotePropertyValue "<div class='guidance'>${($md.Html)}</div>" -Force
    }

    # Build the table selecting the HTML guidance instead of raw
    $rows = $aLLRESULTS |
        Where-Object { $_.ResourceId } |
        Select-Object Resourceid, Type, Signal, Detail, Score,
            @{ Name = 'RESULTGUIDANCE'; Expression = { $_.RESULTGUIDANCE_HTML } }

    # Use -Fragment so we can assemble our own document
    $tableFragment = $rows | ConvertTo-Html -Fragment

    # Assemble the full document
    $htmlContent = @"
<html>
<head>
$CSS
</head>
<body>
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Azure reservation advisor with guidance:</p>
$tableFragment
</body>
</html>
"@

    # Decode once so embedded HTML (<strong>, <ul>, etc.) in cells actually renders
    Add-Type -AssemblyName System.Web
    $finalHtml = [System.Web.HttpUtility]::HtmlDecode($htmlContent)
}
else {
    # Fallback (Option A): plain text guidance with preserved line breaks
    $rows = $aLLRESULTS |
        Where-Object { $_.ResourceId } |
        Select-Object Resourceid, Type, Signal, Detail, Score, RESULTGUIDANCE

    $tableFragment = $rows | ConvertTo-Html -Fragment

    $finalHtml = @"
<html>
<head>
$CSS
</head>
<body>
<h2>Azure underutulized resources Report</h2>
<p>Date: $date</p>
<p>Azure reservation advisor with guidance:</p>
$tableFragment
</body>
</html>
"@
}

$outputHtmlPath = "C:\temp\guidance_underutilized_resources.html"
# Ensure UTF-8 so any unicode renders properly
$finalHtml | Out-File -FilePath $outputHtmlPath -Encoding utf8

Write-Output "HTML report has been saved to $outputHtmlPath"
Invoke-Item -Path $outputHtmlPath


















