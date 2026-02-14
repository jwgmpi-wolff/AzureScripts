
#requires -Modules Az.Accounts, Az.Resources, Az.ResourceGraph

<# =========================
    CONFIG
   ========================= #>

$TenantId               = '72f988bf-86f1-41af-91ab-2d7cd011db47'  # Microsoft tenant
$TargetSubscriptionName = 'wolffentpsub'                           # change to 'Trey Research Finance' if desired

# Optional: path of the helper script that generates clean, no-reasoning guidance text.
$CleanResponderScript   = '.\wolff_ai_foundry_call_HC_noreasoning_cleanonly.ps1'

<# =========================
    CONNECT & CONTEXT
   ========================= #>

function Ensure-AzContext {
    param(
        [string]$TenantId,
        [string]$SubscriptionName
    )
    try {
        # Prefer Managed Identity when running in Azure (VM/Function/Automation)
        Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    }
    catch {
        # Fall back to device authentication when running locally
        Connect-AzAccount -UseDeviceAuthentication -Tenant $TenantId -SubscriptionName $SubscriptionName | Out-Null
    }

    $subscription = Get-AzSubscription -SubscriptionName $SubscriptionName
    if (-not $subscription) {
        throw "Subscription '$SubscriptionName' not found for tenant $TenantId."
    }

    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    return $subscription
}

$Subscription = Ensure-AzContext -TenantId $TenantId -SubscriptionName $TargetSubscriptionName

<# =========================
    RESOURCE GRAPH QUERY
   ========================= #>

$QUERY = @'
advisorresources
| where type == "microsoft.advisor/recommendations"
| where tostring(properties.category) has "Cost"
| where properties.impactedField has "Microsoft.Subscriptions/subscriptions"
| project
    name,
    AffectedResource = tostring(properties.resourceMetadata.resourceId),
    Recommendation   = tostring(properties.shortDescription.problem),
    Impact           = tostring(properties.impact),
    resourceGroup,
    AdditionaInfo    = properties.extendedProperties,
    subscriptionId
'@

$queryresults1 = Search-AzGraph -Query $QUERY -Subscription $Subscription.Id

<# =========================
    SAVINGS CALCULATION
   ========================= #>

function Calculate-Savings {
    param(
        [float] $NetSavings,
        [string]$Term,     # 'P1Y' or 'P3Y'
        [int]   $Days
    )

    $termTotalSavings = switch ($Term) {
        'P1Y' { $NetSavings }
        'P3Y' { $NetSavings / 3 }
        default { 0 }
    }

    $dailySavings = $termTotalSavings / 365
    return [math]::Round(($dailySavings * $Days), 2)
}

<# =========================
    BUILD RECOMMENDATION OBJECTS
   ========================= #>

# Strongly typed arrays
$reservationrecommendations = @()
$aLLRESULTS                 = @()

foreach ($reservationitem in $queryresults1) {

    $ext = $reservationitem.AdditionaInfo
    # Guard against null extended properties
    if (-not $ext) { $ext = [pscustomobject]@{} }

    $netSavings = [float]($ext.annualSavingsAmount)
    $term       = [string]($ext.term)

    $reservobj = [pscustomobject]@{
        Recommendationname          = $reservationitem.name
        AffectedResource            = $reservationitem.AffectedResource
        Recommendation              = $reservationitem.Recommendation
        Impact                      = $reservationitem.Impact
        resourceGroup               = $reservationitem.resourceGroup
        AdditionaInfo               = $ext
        subscriptionId              = $reservationitem.subscriptionId

        region                      = $ext.region
        reservedResourceType        = $ext.reservedResourceType
        annualSavingsAmountbyterm   = $ext.annualSavingsAmount
        savingsCurrency             = $ext.savingsCurrency
        lookbackPeriod              = $ext.lookbackPeriod
        savingsAmount               = $ext.savingsAmount
        targetResourceCount         = $ext.targetResourceCount
        displaySKU                  = $ext.displaySKU
        displayQty                  = $ext.displayQty
        location                    = $ext.location
        vmSize                      = $ext.vmSize
        subId                       = $ext.subId
        scope                       = $ext.scope
        term                        = $term
        sku                         = $ext.sku
        subscriptionname            = $null  # populated below
        netSavings30Days            = Calculate-Savings -NetSavings $netSavings -Term $term -Days 30
        netSavings60Days            = Calculate-Savings -NetSavings $netSavings -Term $term -Days 60
        netSavings90Days            = Calculate-Savings -NetSavings $netSavings -Term $term -Days 90
        netSavings365Days           = Calculate-Savings -NetSavings $netSavings -Term $term -Days 365
        netSavings1095Days          = Calculate-Savings -NetSavings $netSavings -Term $term -Days 1095
    }

    # Safe lookup of subscription name using subId in extended props (when available)
    try {
        if ($ext.subId) {
            $reservobj.subscriptionname = (Get-AzSubscription -SubscriptionId $ext.subId).Name
        } else {
            $reservobj.subscriptionname = $TargetSubscriptionName
        }
    } catch {
        $reservobj.subscriptionname = $TargetSubscriptionName
    }

    $reservationrecommendations += $reservobj
}

<# =========================
    RESULTGUIDANCE FORMATTER
   ========================= #>

function Normalize-Text {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    $t = $s.Trim()
    # Collapse multiple spaces
    $t = [regex]::Replace($t, '\s+', ' ')
    # Remove stray spaces around punctuation
    $t = $t -replace '\s+,', ',' -replace ',\s+', ', ' -replace '\s+;', ';' -replace ';\s+', '; '
    # Ensure space after period when not decimal (preserve 4.13 / 0.0)
    $t = [regex]::Replace($t, '(?<!\d)\.(\S)', '. $1')
    return $t.Trim()
}

function Strip-Decorative {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    $t = $s
    # Remove leading @ and leading 'json {' markers
    $t = [regex]::Replace($t, '^\s*@\s*', '', 'IgnoreCase, Multiline')
    $t = [regex]::Replace($t, '^\s*json\s*\{\s*', '', 'IgnoreCase, Multiline')
    # Remove fenced code block starts (```json, ```powershell, ```), keeping inner content
    $t = [regex]::Replace($t, '^\s*```[^\r\n]*\r?\n?', '', 'IgnoreCase, Multiline')
    # Remove fenced code block ends
    $t = $t -replace '```', ''
    return $t
}

function Insert-BreakAfterRecommendation {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    # Insert CRLF after the word 'Recommendation'
    return [regex]::Replace($s, '\bRecommendation\b\s*', "Recommendation`r`n", 'IgnoreCase')
}

function Split-IntoSentenceChunks {
    param([string]$s)
    $chunks = @()

    if ([string]::IsNullOrWhiteSpace($s)) { return $chunks }

    # Split by newlines into blocks
    foreach ($block in ($s -split "`r?`n")) {
        $b = $block.Trim()
        if (-not $b) { continue }

        # Split by semicolons
        foreach ($semi in ($b -split ';')) {
            $semiTrim = $semi.Trim()
            if (-not $semiTrim) { continue }

            # Split by periods NOT part of decimals: (?<!\d)\.(?!\d)
            $pieces = [regex]::Split($semiTrim, '(?<!\d)\.(?!\d)')
            foreach ($p in $pieces) {
                $pt = $p.Trim()
                if ($pt) { $chunks += $pt }
            }
        }
    }
    return $chunks
}

function Format-ResultGuidance {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return '' }

    $clean0    = Strip-Decorative $Raw
    $clean1    = Normalize-Text  $clean0
    $withBreak = Insert-BreakAfterRecommendation $clean1

    # The first line is the header; remainder becomes bullets
    $lines  = $withBreak -split "`r?`n"
    $header = ($lines | Select-Object -First 1).Trim()
    $rest   = ($lines | Select-Object -Skip 1) -join ' '

    $chunks = Split-IntoSentenceChunks (Normalize-Text $rest)

    $sb = New-Object System.Text.StringBuilder
    if ($header) { [void]$sb.AppendLine($header) } # keep header; comment out to suppress
    foreach ($c in $chunks) {
        if ($c) { [void]$sb.AppendLine("- $c") }
    }

    # Normalize to Windows CRLF
    return ([regex]::Replace($sb.ToString().TrimEnd(), "`r?`n", "`r`n"))
}

<# =========================
    INVOKE CLEAN RESPONDER & BUILD aLLRESULTS
   ========================= #>

# ensure path context (optional)
# Set-Location -Path "C:\Users\jerrywolff\OneDrive - Microsoft\Documents\azure\PS1"

foreach ($rec in ($reservationrecommendations | Where-Object { $_.subscriptionname -ne $null })) {

    Write-Host ("{0}" -f $rec.Recommendationname) -ForegroundColor Cyan

    # Call helper to get plain guidance (stderr+stdout merged)
    $response = & $CleanResponderScript ("provide a recommendation for {0}" -f ($rec | Out-String)) 2>&1

    # 1) Decode HTML entities so &lt;/think&gt; becomes </think>
    Add-Type -AssemblyName System.Web
    $decoded = [System.Web.HttpUtility]::HtmlDecode($response)

    # 2) Extract everything after closing </think> tag (case-insensitive)
    $match = [regex]::Match($decoded, '</think\s*>', 'IgnoreCase')
    $afterThink = if ($match.Success) { $decoded.Substring($match.Index + $match.Length) } else { $decoded }

    # 3) Trim + Normalize line endings
    $rawResult = [regex]::Replace($afterThink.Trim(), "`r?`n", "`r`n")

    # 4) Apply strict formatter: newline after 'Recommendation', bullets, strip leading '@', strip code fences, preserve decimals
    $result = Format-ResultGuidance $rawResult

    $resultobj = [pscustomobject]@{
        subscriptionname  = $rec.subscriptionname
        subscriptionId    = $rec.subscriptionId
        targetResourceCount= $rec.targetResourceCount
        term              = $rec.term
        vmSize            = $rec.vmSize
        region            = $rec.region
        Recommendationname= $rec.Recommendationname
        Recommendation    = $rec.Recommendation
        displaySKU        = $rec.displaySKU
        lookbackPeriod    = $rec.lookbackPeriod
        RESULTGUIDANCE    = $result
    }

    $aLLRESULTS += $resultobj
}

<# =========================
    HTML REPORT
   ========================= #>

$date = Get-Date -Format 'dd MMMM yyyy'
$CSS = @"
<title>Azure reservation instance Plan Forecast Report from Advisor: $date</title>
<style>
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
        vertical-align: top;
        white-space: pre-wrap; /* allow multi-line guidance */
    }
</style>
"@

$htmlContent = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Azure reservation advisor with guidance:</p>
"@ + (
    $aLLRESULTS |
    Where-Object { $_.subscriptionname -ne $null } |
    Select-Object subscriptionname, subscriptionId, targetResourceCount, term, vmSize, region, Recommendationname, Recommendation, displaySKU, lookbackPeriod, RESULTGUIDANCE |
    ConvertTo-Html -Head $CSS
)

$outputHtmlPath = 'C:\temp\guidancereservation_plan_from_advisor.html'
$htmlContent | Out-File -FilePath $outputHtmlPath -Encoding UTF8
Write-Output "HTML report has been saved to $outputHtmlPath"
Invoke-Item -Path $outputHtmlPath

<# =========================
    OPTIONAL: CSV EXPORT
   ========================= #>

$reservationrecommendations |
    Where-Object { $_ -ne "" } |
    Select-Object Recommendationname, AffectedResource, Recommendation, Impact, AdditionaInfo, subscriptionId, subscriptionname, region, reservedResourceType, term, annualSavingsAmountbyterm, savingsCurrency, lookbackPeriod, savingsAmount, targetResourceCount, displaySKU, displayQty, location, vmSize, subId, scope, netSavings30Days, netSavings60Days, netSavings90Days, netSavings365Days, netSavings1095Days |
    Export-Csv -Path 'C:\temp\reservation_plan_from_advisor.csv' -NoTypeInformation -Encoding UTF8

<# =========================
    SUMMARY (optional)
   ========================= #>

$groupedData = $reservationrecommendations |
    Where-Object { $_ -ne "" } |
    Group-Object -Property recommendation, AffectedResource, reservedResourceType, term, sku, vmSize, region, subscriptionname

$summaryResults = @()

foreach ($group in $groupedData) {
    $totalNetSavings30Days  = ($group.Group | Measure-Object -Property netSavings30Days  -Sum).Sum
    $totalNetSavings60Days  = ($group.Group | Measure-Object -Property netSavings60Days  -Sum).Sum
    $totalNetSavings90Days  = ($group.Group | Measure-Object -Property netSavings90Days  -Sum).Sum
    $totalNetSavings365Days = ($group.Group | Measure-Object -Property netSavings365Days -Sum).Sum
    $totalNetSavings1095Days= ($group.Group | Measure-Object -Property netSavings1095Days-Sum).Sum

    $fields = $group.Name.Split(',')
    $affectedResource     = $fields[0].Trim()
    $reservedResourceType = $fields[1].Trim()
    $termField            = $fields[2].Trim()
    $skuField             = $fields[3].Trim()
    $vmSizeField          = $fields[4].Trim()
    $regionField          = if ($fields.Count -gt 5) { $fields[5].Trim() } else { 'All' }
    $subscriptionname     = if ($fields.Count -gt 6) { $fields[6].Trim() } else { $TargetSubscriptionName }

    if ([string]::IsNullOrEmpty($vmSizeField)) {
        $vmSizeField  = 'All'
        $regionField  = 'All'
    }
    if ($group.Group[0].displaySKU -eq 'Compute_Savings_Plan' -or $group.Group[0].displaySKU -eq $null) {
        $reservedResourceType = 'Compute_Savings_Plan'
        $skuField             = 'Compute_Savings_Plan'
        $vmSizeField          = 'All'
        $regionField          = 'All'
    }

    Write-Host "AffectedResource: $affectedResource"
    Write-Host "reservedResourceType: $reservedResourceType"
    Write-Host "term: $termField"
    Write-Host "sku: $skuField"
    Write-Host "vmsize: $vmSizeField"
    Write-Host "region: $regionField"
    Write-Host "subscriptionname: $subscriptionname"

    $summaryResult = [pscustomobject]@{
        AffectedResource     = $affectedResource
        reservedResourceType = $reservedResourceType
        term                 = $termField
        sku                  = $skuField
        vmsize               = $vmSizeField
        region               = $regionField
        subscriptionname     = $subscriptionname
        Count                = $group.Count
        netSavings30Days     = $totalNetSavings30Days
        netSavings60Days     = $totalNetSavings60Days
        netSavings90Days     = $totalNetSavings90Days
        netSavings365Days    = $totalNetSavings365Days
        netSavings1095Days   = $totalNetSavings1095Days
        displaysku           = $group.Group[0].displaySKU
        Recommendation       = $group.Group[0].Recommendationname
    }
    $summaryResults += $summaryResult
}

# You can export $summaryResults if desired:
# $summaryResults | Export-Csv -Path 'C:\temp\reservation_summary.csv' -NoTypeInformation -Encoding UTF8
