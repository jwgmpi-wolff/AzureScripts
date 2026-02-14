
#requires -Modules Az.Accounts, Az.Resources, Az.ResourceGraph

<# ======================
   Sign-in & Subscription
====================== #>

# Connect using managed identity
$account = Connect-AzAccount -Identity
$account | Format-List *

# Get and set the subscription context
$subscription = Get-AzSubscription -SubscriptionName 'wolffentpsub'
if (-not $subscription) { throw "Subscription 'wolffentpsub' not found." }
Set-AzContext -SubscriptionId $subscription.Id

<# ======================
   Kusto Resource Graph
====================== #>

# Query Advisor recommendations (Cost category, subscription-level scope)
$QUERY = @'
advisorresources
| where type == "microsoft.advisor/recommendations"
| where tostring(properties.category) has "Cost"
| where properties.impactedField has "Microsoft.Subscriptions/subscriptions"
| project name,
         AffectedResource=tostring(properties.resourceMetadata.resourceId),
         Recommendation=tostring(properties.shortDescription.problem),
         Impact=tostring(properties.impact),
         resourceGroup,
         AdditionaInfo=properties.extendedProperties,
         subscriptionId
'@

$queryresults1 = Search-AzGraph -Query $QUERY -Subscription $subscription.Id

# Optional: inspect extended properties (spelled "AdditionaInfo" in the projection)
# $($queryresults1.AdditionaInfo) | Format-List *

<# ==============
   Savings helper
=============== #>

function Calculate-Savings {
    param (
        [float]$NetSavings,
        [string]$Term,  # 'P1Y' or 'P3Y'
        [int]$Days
    )
    $termtotalsavings = switch ($Term) {
        'P1Y' { $NetSavings }
        'P3Y' { $NetSavings / 3 }
        default { 0 }
    }
    $dailySavings = $termtotalsavings / 365
    return ($dailySavings * $Days)
}

<# =======================
   Collect recommendation
======================== #>

# Ensure arrays are initialized
$reservationrecommendations = @()

foreach ($reservationitem in $queryresults1) {

    $reservobj = New-Object PSObject

    # Base fields from the query
    $reservobj | Add-Member -MemberType NoteProperty -Name Recommendationname -Value $reservationitem.name
    $reservobj | Add-Member -MemberType NoteProperty -Name AffectedResource   -Value $reservationitem.AffectedResource
    $reservobj | Add-Member -MemberType NoteProperty -Name Recommendation     -Value $reservationitem.Recommendation
    $reservobj | Add-Member -MemberType NoteProperty -Name Impact             -Value $reservationitem.Impact
    $reservobj | Add-Member -MemberType NoteProperty -Name resourceGroup      -Value $reservationitem.resourceGroup
    $reservobj | Add-Member -MemberType NoteProperty -Name AdditionaInfo      -Value $reservationitem.AdditionaInfo  # note: spelling from query
    $reservobj | Add-Member -MemberType NoteProperty -Name subscriptionId     -Value $reservationitem.subscriptionId

    # Extended properties (guard with null checks)
    $ext = $reservationitem.AdditionaInfo
    $reservobj | Add-Member -MemberType NoteProperty -Name region                 -Value $ext.region
    $reservobj | Add-Member -MemberType NoteProperty -Name reservedResourceType   -Value $ext.reservedResourceType
    $reservobj | Add-Member -MemberType NoteProperty -Name annualSavingsAmountbyterm -Value $ext.annualSavingsAmount
    $reservobj | Add-Member -MemberType NoteProperty -Name savingsCurrency        -Value $ext.savingsCurrency
    $reservobj | Add-Member -MemberType NoteProperty -Name lookbackPeriod         -Value $ext.lookbackPeriod
    $reservobj | Add-Member -MemberType NoteProperty -Name savingsAmount          -Value $ext.savingsAmount
    $reservobj | Add-Member -MemberType NoteProperty -Name targetResourceCount    -Value $ext.targetResourceCount
    $reservobj | Add-Member -MemberType NoteProperty -Name displaySKU             -Value $ext.displaySKU
    $reservobj | Add-Member -MemberType NoteProperty -Name displayQty             -Value $ext.displayQty
    $reservobj | Add-Member -MemberType NoteProperty -Name location               -Value $ext.location
    $reservobj | Add-Member -MemberType NoteProperty -Name vmSize                 -Value $ext.vmSize
    $reservobj | Add-Member -MemberType NoteProperty -Name subId                  -Value $ext.subId
    $reservobj | Add-Member -MemberType NoteProperty -Name scope                  -Value $ext.scope
    $reservobj | Add-Member -MemberType NoteProperty -Name term                   -Value $ext.term
    $reservobj | Add-Member -MemberType NoteProperty -Name sku                    -Value $ext.sku

    # Subscription name lookup (safe)
    $subName = $null
    if ($ext.subId) {
        try {
            $subName = (Get-AzSubscription -SubscriptionId $ext.subId).Name
        } catch { $subName = $null }
    }
    $reservobj | Add-Member -MemberType NoteProperty -Name subscriptionname -Value $subName

    # Savings projections
    $netSavings = [float]($ext.annualSavingsAmount)
    $term       = $ext.term

    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings30Days   -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 30)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings60Days   -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 60)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings90Days   -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 90)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings365Days  -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 365)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings1095Days -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 1095)

    [array]$reservationrecommendations += $reservobj
}

<# ======================
   Formatter functions
====================== #>

function Normalize-Text {
    param ([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    $t = $s.Trim()
    # Collapse multiple spaces
    $t = [regex]::Replace($t, '\s+', ' ')
    # Remove stray spaces around punctuation
    $t = $t -replace '\s+,', ',' -replace ',\s+', ', ' -replace '\s+;', ';' -replace ';\s+', '; '
    # Ensure space after period when not part of a decimal
    $t = [regex]::Replace($t, '(?<!\d)\.(\S)', '. $1')
    return $t.Trim()
}

function Insert-BreakAfterRecommendation {
    param ([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    # Case-insensitive, insert CRLF immediately after the word Recommendation
    return [regex]::Replace($s, '(?i)\bRecommendation\b\s*', "Recommendation`r`n")
}

function Split-IntoSentenceChunks {
    param ([string]$s)
    # Split on newlines → semicolons → periods not belonging to decimals
    $chunks = @()
    foreach ($block in ($s -split "`r?`n")) {
        $block = $block.Trim()
        if (-not $block) { continue }
        foreach ($semi in ($block -split ';')) {
            $semi = $semi.Trim()
            if (-not $semi) { continue }
            # Split on periods that are NOT decimals: (?<!\d)\.(?!\d)
            $pieces = [System.Text.RegularExpressions.Regex]::Split($semi, '(?<!\d)\.(?!\d)')
            foreach ($p in $pieces) {
                $p = $p.Trim()
                if ($p) { $chunks += $p }
            }
        }
    }
    return $chunks
}

function Strip-Decorative {
    param ([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return "" }
    $t = $s
    # Remove markdown code fences (triple backticks)
    $t = [regex]::Replace($t, '```.+?```', '', 'Singleline')
    # Remove LaTeX \boxed{...} (strip opening and trailing })
    $t = [regex]::Replace($t, '\\boxed\s*\{', '')
    $t = $t -replace '\}', ''
    # Remove leading '@' if present
    $t = [regex]::Replace($t, '^\s*@', '')
    return $t
}

function Format-ResultGuidance {
    param (
        [string]$Raw
    )
    if ([string]::IsNullOrWhiteSpace($Raw)) { return "" }

    $norm      = Normalize-Text (Strip-Decorative $Raw)
    $withBreak = Insert-BreakAfterRecommendation $norm

    # Header (first line) + remainder
    $lines = $withBreak -split "`r?`n"
    $header = ($lines | Select-Object -First 1).Trim()
    $rest   = ($lines | Select-Object -Skip 1) -join ' '

    # Build bullets from sentence chunks
    $chunks = Split-IntoSentenceChunks (Normalize-Text $rest)
    $sb = New-Object System.Text.StringBuilder
    if ($header) { [void]$sb.AppendLine($header) }
    foreach ($c in $chunks) {
        $c = Normalize-Text $c
        if ($c) { [void]$sb.AppendLine("- $c") }
    }

    # Normalize CRLF
    return (($sb.ToString()).TrimEnd() -replace "`r?`n", "`r`n")
}

<# ============================
   Invoke model & clean output
============================ #>

# Folder where the helper script lives
Set-Location "C:\Users\jerrywolff\OneDrive - Microsoft\Documents\azure\PS1"

# Collect formatted guidance rows
$aLLRESULTS = @()

foreach ($rec in ($reservationrecommendations | Where-Object { $_.subscriptionname -ne $null })) {

    Write-Host "$($rec.name)" -ForegroundColor Cyan

    # Call your clean-output model wrapper (returns HTML-encoded; we will decode)
    $response = & .\wolff_ai_foundry_call_HC_noreasoning_cleanonly_formatoutput.ps1  "provide a recommendation for $($rec)"  *>&1

    # 1) Decode HTML entities
    Add-Type -AssemblyName System.Web
    $decoded = [System.Web.HttpUtility]::HtmlDecode($response)

    # 2) Extract everything after the first closing </think>
    $pattern = '</think\s*>'   # already decoded
    $match   = [System.Text.RegularExpressions.Regex]::Match($decoded, $pattern, 'IgnoreCase')

    if ($match.Success) {
        $startIndex = $match.Index + $match.Length
        $afterThink = $decoded.Substring($startIndex)

        # 3) Trim
        $result = $afterThink.Trim()

        # 4) Normalize CRLF
        $result = $result -replace "`r?`n", "`r`n"

        # 5) Apply strict formatter: newline after 'Recommendation', bullets, strip '@', strip boxes/fences
        $result = Format-ResultGuidance $result

        # Build final output object for HTML
        $resultobj = New-Object PSObject

        $resultobj | Add-Member -MemberType NoteProperty -Name subscriptionname   -Value $rec.subscriptionname
        $resultobj | Add-Member -MemberType NoteProperty -Name subscriptionId     -Value $rec.subscriptionId
        $resultobj | Add-Member -MemberType NoteProperty -Name targetResourceCount -Value $rec.targetResourceCount
        $resultobj | Add-Member -MemberType NoteProperty -Name term               -Value $rec.term
        $resultobj | Add-Member -MemberType NoteProperty -Name vmSize             -Value $rec.vmSize
        $resultobj | Add-Member -MemberType NoteProperty -Name region             -Value $rec.region
        $resultobj | Add-Member -MemberType NoteProperty -Name Recommendationname -Value $rec.Recommendationname
        $resultobj | Add-Member -MemberType NoteProperty -Name Recommendation     -Value $rec.Recommendation
        $resultobj | Add-Member -MemberType NoteProperty -Name displaySKU         -Value $rec.displaySKU
        $resultobj | Add-Member -MemberType NoteProperty -Name lookbackPeriod     -Value $rec.lookbackPeriod
        $resultobj | Add-Member -MemberType NoteProperty -Name RESULTGUIDANCE     -Value "$result"

        [array]$aLLRESULTS += $resultobj
    }
}

<# =====================
   HTML report (GUIDE)
===================== #>

$date = Get-Date -Format 'dd MMMM yyyy'
$CSS = @"
<Title>Azure reservation instance Plan Forecast Report from Advisor: $date</Title>
<Style>
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
    color: #6D929B;
}
</Style>
"@

$htmlContent = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Azure reservation advisor with guidance:</p>
"@ + ( $aLLRESULTS |
        Where-Object { $_.subscriptionname -ne $null } |
        Select-Object subscriptionname,
                      subscriptionId,
                      targetResourceCount,
                      term,
                      vmSize,
                      region,
                      Recommendationname,
                      Recommendation,
                      displaySKU,
                      lookbackPeriod,
                      RESULTGUIDANCE |
        ConvertTo-Html -Head $CSS )

$outputHtmlPath = "c:\temp\guidancereservation_plan_from_advisor.html"
$htmlContent | Out-File -FilePath $outputHtmlPath -Encoding UTF8
Write-Output "HTML report has been saved to $outputHtmlPath"
Invoke-Item -Path $outputHtmlPath

<# =====================
   Optional: CSV export
===================== #>
# If you want the earlier CSV (leave as-is or comment out):
# $reservationrecommendations | Where-Object { $_ -ne "" } |
#     Select-Object Recommendationname,
#                   AffectedResource,
#                   Recommendation,
#                   Impact,
#                   AdditionaInfo,
#                   subscriptionId,
#                   subscriptionname,
#                   region,
#                   reservedResourceType,
#                   term,
#                   annualSavingsAmountbyterm,
#                   savingsCurrency,
#                   lookbackPeriod,
#                   savingsAmount,
#                   targetResourceCount,
#                   displaySKU,
#                   displayQty,
#                   location,
#                   vmSize,
#                   subId,
#                   scope,
#                   netSavings30Days,
#                   netSavings60Days,
#                   netSavings90Days,
#                   netSavings365Days,
#                   netSavings1095Days |
#     Export-Csv -Path "C:\temp\reservation_plan_from_advisor.csv" -NoTypeInformation -Encoding UTF8

<# ======================
   Summary aggregation
====================== #>

$groupedData = $reservationrecommendations |
    Where-Object { $_ -ne "" } |
    Group-Object -Property recommendation, AffectedResource, reservedResourceType, term, sku, vmsize, region, subscriptionname

$summaryResults = @()

foreach ($group in $groupedData) {
    $totalNetSavings30Days  = ($group.Group | Measure-Object -Property netSavings30Days  -Sum).Sum
    $totalNetSavings60Days  = ($group.Group | Measure-Object -Property netSavings60Days  -Sum).Sum
    $totalNetSavings90Days  = ($group.Group | Measure-Object -Property netSavings90Days  -Sum).Sum
    $totalNetSavings365Days = ($group.Group | Measure-Object -Property netSavings365Days -Sum).Sum
    $totalNetSavings1095Days= ($group.Group | Measure-Object -Property netSavings1095Days -Sum).Sum

    $fields = $group.Name.Split(',')
    $affectedResource     = $fields[0].Trim()
    $reservedResourceType = $fields[1].Trim()
    $term                 = $fields[2].Trim()
    $sku                  = $fields[3].Trim()
    $vmsize               = $fields[4].Trim()
    # $region             = $fields[5].Trim()
    $subscriptionname     = $fields[6].Trim()

    # vmsize/Compute_Savings_Plan handling
    if ([string]::IsNullOrEmpty($vmsize)) {
        if ([string]::IsNullOrEmpty($group.Group[0].displaysku) -and [string]::IsNullOrEmpty($group.Group[0].location)) {
            $sku  = $group.Group[0].sku
            $term = $fields[1].Trim()
            $vmsize = 'All'
            $region = 'All'
        }
    }

    if ($group.Group[0].displaysku -eq 'Compute_Savings_Plan' -or $null -eq $group.Group[0].displaysku) {
        $reservedResourceType = 'Compute_Savings_Plan'
        $term    = $fields[1].Trim()
        $vmsize  = 'All'
        $sku     = 'Compute_Savings_Plan'
        $region  = 'All'
    }

    Write-Host "AffectedResource: $affectedResource"
    Write-Host "reservedResourceType: $reservedResourceType"
    Write-Host "term: $term"
    Write-Host "sku: $sku"
    Write-Host "vmsize: $vmsize"
    Write-Host "region: $region"
    Write-Host "subscriptionname: $subscriptionname"

    $summaryResult = [PSCustomObject]@{
        AffectedResource      = $affectedResource
        reservedResourceType  = $reservedResourceType
        term                  = $term
        sku                   = $sku
        vmsize                = $vmsize
        region                = $region
        subscriptionname      = $subscriptionname
        Count                 = $group.Count
        netSavings30Days      = $totalNetSavings30Days
        netSavings60Days      = $totalNetSavings60Days
        netSavings90Days      = $totalNetSavings90Days
        netSavings365Days     = $totalNetSavings365Days
        netSavings1095Days    = $totalNetSavings1095Days
        displaysku            = $group.Group[0].sku
        Recommendation        = $group.Group[0].Recommendation  # fixed: use first group's recommendation
    }
    $summaryResults += $summaryResult
}
