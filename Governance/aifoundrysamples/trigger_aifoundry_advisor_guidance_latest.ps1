
<# ============================
 Azure Advisor Reservations Forecast + Guidance
 (CR/LF sentence separation embedded)
============================= #>

# 1) Connect to Azure (Managed Identity first; fallback commented)
try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
} catch {
    Write-Warning "Managed Identity sign-in failed. Uncomment the line below to use device code auth."
    # Connect-AzAccount -UseDeviceAuthentication -Tenant 72f988bf-86f1-41af-91ab-2d7cd011db47 -SubscriptionName 'Trey Research Finance'
}

# Optional: Display account (safe)
# $account | Format-List *

# 2) Select/resolve subscription context
$SUB = Get-AzSubscription -SubscriptionName 'wolffentpsub'
if (-not $SUB) { throw "Subscription 'wolffentpsub' not found." }
Select-AzSubscription -SubscriptionId $SUB.Id | Out-Null

# 3) Helper: Convert guidance into CR/LF + blank line separated plain text
function Convert-GuidanceToCRLF {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    # Normalize Windows/Mac line endings and trim
    $norm = ($Text -replace "`r?`n", "`r`n").Trim()

    # Remove common code-fence noise and lone labels
    $norm = $norm -replace '^\s*```json\s*$', '', 'Multiline'
    $norm = $norm -replace '^\s*```$', '', 'Multiline'
    $norm = $norm -replace '^\s*json\s*$', '', 'Multiline'
    $norm = $norm -replace '^\s*```.*$', '', 'Multiline'
    $norm = $norm -replace '^\s*\{?\s*$', '', 'Multiline'
    $norm = $norm -replace '^\s*\}?\s*$', '', 'Multiline'

    if ([string]::IsNullOrWhiteSpace($norm)) { return $norm }

    # Collapse excessive internal whitespace (but preserve periods)
    $norm = ($norm -replace '\s+', ' ').Trim()

    # Split into sentences (basic heuristic: ., !, ? followed by space)
    # Protect common abbreviations by not splitting when period is followed by lowercase (rudimentary)
    $sentences = [System.Text.RegularExpressions.Regex]::Split(
        $norm,
        '(?<=[\.!?])\s+(?=[A-Z0-9])'
    )

    # Join with CR/LF + blank line
    $joined = ($sentences | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }) -join "`r`n`r`n"
    return $joined
}
function Convert-GuidanceToCRLF {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    # Normalize Windows/Mac line endings and trim
    $norm = ($Text -replace "`r?`n", "`r`n").Trim()

    # Strip common code-fence noise (multiline-aware via (?m))
    # Remove lines like ```json, ```, 'json', bare braces, or generic ```
    $norm = $norm -replace '(?m)^\s*```json\s*$', ''
    $norm = $norm -replace '(?m)^\s*```\s*$', ''
    $norm = $norm -replace '(?m)^\s*json\s*$', ''
    $norm = $norm -replace '(?m)^\s*```\S*\s*$', ''
    $norm = $norm -replace '(?m)^\s*\{\s*$', ''
    $norm = $norm -replace '(?m)^\s*\}\s*$', ''

    if ([string]::IsNullOrWhiteSpace($norm)) { return $norm }

    # Collapse excessive internal whitespace (preserve periods); then trim
    $norm = ($norm -replace '\s+', ' ').Trim()

    # Split into sentences. This is a simple heuristic:
    #   - split on [.?!] followed by whitespace and a capital/number
    #   - protect abbreviations by not splitting when the next char is lowercase
    $sentences = [System.Text.RegularExpressions.Regex]::Split(
        $norm,
        '(?<=[\.\?\!])\s+(?=[A-Z0-9])'
    )

    # Join with CR/LF + blank line between sentences
    $joined = ($sentences |
        ForEach-Object { $_.Trim() } |
        Where-Object  { $_.Length -gt 0 }) -join "`r`n`r`n"

    return $joined
}


# 4) Build Kusto query for Advisor (Cost category / reservation-related hints)
$advisorsavingsreport = ''
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

# 5) Execute Resource Graph query against selected subscription
$queryresults1 = Search-AzGraph -Query $QUERY -Subscription $SUB.Id

# Uncomment for inspection:
# $($queryresults1.AdditionaInfo) | Format-List *

# 6) Savings calculator (annual → daily → window totals)
function Calculate-Savings {
    param (
        [float]$NetSavings,
        [string]$Term,
        [int]$Days
    )
    if ($Term -eq 'P1Y') { $termTotal = $NetSavings }
    elseif ($Term -eq 'P3Y') { $termTotal = $NetSavings / 3 }
    else { $termTotal = 0 }

    $daily = $termTotal / 365
    return $daily * $Days
}

# 7) Materialize row objects
[array]$reservationrecommendations = @()

# Uncomment for inspection:
# $queryresults1 | Format-List *

foreach ($reservationitem in $queryresults1) {
    $reservobj = New-Object PSObject
    $netSavings = [float]$reservationitem.AdditionaInfo.annualSavingsAmount
    $term       = [string]$reservationitem.AdditionaInfo.term

    $reservobj | Add-Member -MemberType NoteProperty -Name Recommendationname         -Value $reservationitem.name
    $reservobj | Add-Member -MemberType NoteProperty -Name AffectedResource          -Value $reservationitem.AffectedResource
    $reservobj | Add-Member -MemberType NoteProperty -Name Recommendation            -Value $reservationitem.Recommendation
    $reservobj | Add-Member -MemberType NoteProperty -Name Impact                    -Value $reservationitem.Impact
    $reservobj | Add-Member -MemberType NoteProperty -Name resourceGroup             -Value $reservationitem.resourceGroup
    $reservobj | Add-Member -MemberType NoteProperty -Name AdditionaInfo             -Value $reservationitem.AdditionaInfo
    $reservobj | Add-Member -MemberType NoteProperty -Name subscriptionId            -Value $reservationitem.subscriptionId

    $reservobj | Add-Member -MemberType NoteProperty -Name region                    -Value $reservationitem.AdditionaInfo.region
    $reservobj | Add-Member -MemberType NoteProperty -Name reservedResourceType      -Value $reservationitem.AdditionaInfo.reservedResourceType
    $reservobj | Add-Member -MemberType NoteProperty -Name annualSavingsAmountbyterm -Value $reservationitem.AdditionaInfo.annualSavingsAmount
    $reservobj | Add-Member -MemberType NoteProperty -Name savingsCurrency           -Value $reservationitem.AdditionaInfo.savingsCurrency
    $reservobj | Add-Member -MemberType NoteProperty -Name lookbackPeriod            -Value $reservationitem.AdditionaInfo.lookbackPeriod
    $reservobj | Add-Member -MemberType NoteProperty -Name savingsAmount             -Value $reservationitem.AdditionaInfo.savingsAmount
    $reservobj | Add-Member -MemberType NoteProperty -Name targetResourceCount       -Value $reservationitem.AdditionaInfo.targetResourceCount
    $reservobj | Add-Member -MemberType NoteProperty -Name displaySKU                -Value $reservationitem.AdditionaInfo.displaySKU
    $reservobj | Add-Member -MemberType NoteProperty -Name displayQty                -Value $reservationitem.AdditionaInfo.displayQty
    $reservobj | Add-Member -MemberType NoteProperty -Name location                  -Value $reservationitem.AdditionaInfo.location
    $reservobj | Add-Member -MemberType NoteProperty -Name vmSize                    -Value $reservationitem.AdditionaInfo.vmSize
    $reservobj | Add-Member -MemberType NoteProperty -Name subId                     -Value $reservationitem.AdditionaInfo.subId
    $reservobj | Add-Member -MemberType NoteProperty -Name scope                     -Value $reservationitem.AdditionaInfo.scope
    $reservobj | Add-Member -MemberType NoteProperty -Name term                      -Value $term
    $reservobj | Add-Member -MemberType NoteProperty -Name sku                       -Value $reservationitem.AdditionaInfo.sku
    $reservobj | Add-Member -MemberType NoteProperty -Name subscriptionname          -Value (Get-AzSubscription -SubscriptionId $reservationitem.AdditionaInfo.subId).Name

    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings30Days          -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 30)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings60Days          -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 60)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings90Days          -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 90)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings365Days         -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 365)
    $reservobj | Add-Member -MemberType NoteProperty -Name netSavings1095Days        -Value (Calculate-Savings -NetSavings $netSavings -Term $term -Days 1095)

    $reservationrecommendations += $reservobj
}

# 8) Detailed report (HTML + CSV)
$date = Get-Date -Format 'dd MMMM yyyy'
$totalCostToZeroOverages = 0


$CSS = @"
<Title> Azure reservation instance Plan Forecast Report from Advisor: $date </Title>
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
    white-space: pre-wrap;   /* <-- preserves CR/LF */
}
</Style>
"@


$htmlContent = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Total cost of additional hours to zero overages: $$totalCostToZeroOverages</p>
"@ + (
    $reservationrecommendations |
    Select-Object Recommendationname,
                  AffectedResource,
                  Recommendation,
                  Impact,
                  AdditionaInfo,
                  subscriptionId,
                  subscriptionname,
                  region,
                  reservedResourceType,
                  term,
                  annualSavingsAmountbyterm,
                  savingsCurrency,
                  lookbackPeriod,
                  savingsAmount,
                  targetResourceCount,
                  displaySKU,
                  displayQty,
                  location,
                  vmSize,
                  subId,
                  scope,
                  sku,
                  netSavings30Days,
                  netSavings60Days,
                  netSavings90Days,
                  netSavings365Days,
                  netSavings1095Days |
    ConvertTo-Html -Head $CSS
)

$outputHtmlPath = "C:\temp\reservation_plan_from_advisor.html"
$htmlContent | Out-File -FilePath $outputHtmlPath -Encoding UTF8
Write-Output "HTML report has been saved to $outputHtmlPath"
Invoke-Item -Path $outputHtmlPath

# CSV
$reservationrecommendations |
    Where-Object { $_ -ne "" } |
    Select-Object Recommendationname,
                  AffectedResource,
                  Recommendation,
                  Impact,
                  AdditionaInfo,
                  subscriptionId,
                  subscriptionname,
                  region,
                  reservedResourceType,
                  term,
                  annualSavingsAmountbyterm,
                  savingsCurrency,
                  lookbackPeriod,
                  savingsAmount,
                  targetResourceCount,
                  displaySKU,
                  displayQty,
                  location,
                  vmSize,
                  subId,
                  scope,
                  netSavings30Days,
                  netSavings60Days,
                  netSavings90Days,
                  netSavings365Days,
                  netSavings1095Days |
    Export-Csv -Path "C:\temp\reservation_plan_from_advisor.csv" -NoTypeInformation -Encoding UTF8

# 9) Summary grouping (unchanged logic)
$groupedData = $reservationrecommendations | Where-Object { $_ -ne "" } |
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
    # $region from fields[5] is often empty; keep computed logic below
    $subscriptionname     = $fields[6].Trim()

    if ([string]::IsNullOrEmpty($vmsize)) {
        $sku      = $group.Group[0].sku
        $term     = $fields[1].Trim()
        $vmsize   = "All"
        $region   = "All"
    }

    if ($group.Group[0].displaysku -eq "Compute_Savings_Plan" -or $group.Group[0].displaysku -eq $null) {
        $reservedResourceType = "Compute_Savings_Plan"
        $term                 = $fields[1].Trim()
        $vmsize               = "All"
        $sku                  = "Compute_Savings_Plan"
        $region               = "All"
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
        Recommendation        = $reservationitem.name
    }
    $summaryResults += $summaryResult
}


# === Foundry guidance call (unchanged invocation) ===
$response = & .\wolff_ai_foundry_call_HC_noreasoning_cleanonly_poc2.ps1 "provide a recommendation for $($rec)" *>&1

# 1) Decode HTML entities so &lt;/think&gt; becomes </think>
Add-Type -AssemblyName System.Web
$decoded = [System.Web.HttpUtility]::HtmlDecode($response)

# 2) Find the first closing </think> tag (case-insensitive), and extract everything after it
$pattern  = '</think\s*>'         # allows optional whitespace before '>'
$match    = [System.Text.RegularExpressions.Regex]::Match($decoded, $pattern, 'IgnoreCase')

if ($match.Success) {
    $startIndex = $match.Index + $match.Length
    $afterThink = $decoded.Substring($startIndex)

    # 3) Trim leading/trailing whitespace
    $result = $afterThink.Trim()

    # 4) Normalize line endings (Windows) and scrub minimal artifacts (keep only valid text)
    $resultclean = ($result -replace "`r?`n","`r`n")

    # 5) Convert to CR/LF + blank line sentence-separated text
    $guidanceText = Convert-GuidanceToCRLF -Text $resultclean

    # Build object for guidance table
    $resultobj = New-Object PSObject
    $resultobj | Add-Member -MemberType NoteProperty -Name subscriptionname  -Value $($rec.subscriptionname)
    $resultobj | Add-Member -MemberType NoteProperty -Name subscriptionId    -Value $($rec.subscriptionId)
    $resultobj | Add-Member -MemberType NoteProperty -Name targetResourceCount -Value $($rec.targetResourceCount)
    $resultobj | Add-Member -MemberType NoteProperty -Name term              -Value $($rec.term)
    $resultobj | Add-Member -MemberType NoteProperty -Name vmSize            -Value $($rec.vmSize)
    $resultobj | Add-Member -MemberType NoteProperty -Name region            -Value $($rec.region)
    $resultobj | Add-Member -MemberType NoteProperty -Name Recommendationname -Value $($rec.Recommendationname)
    $resultobj | Add-Member -MemberType NoteProperty -Name Recommendation    -Value $($rec.Recommendation)
    $resultobj | Add-Member -MemberType NoteProperty -Name displaySKU        -Value $($rec.displaySKU)
    $resultobj | Add-Member -MemberType NoteProperty -Name lookbackPeriod    -Value $($rec.lookbackPeriod)

    # IMPORTANT: sentence-separated text (CR/LF + blank line)
    $resultobj | Add-Member -MemberType NoteProperty -Name RESULTGUIDANCE    -Value $guidanceText

    [array]$aLLRESULTS += $resultobj
}

# 11) Guidance report: CR/LF preserved via CSS white-space: pre-wrap
$guidanceHtml = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Azure reservation advisor with guidance:</p>
"@ + (
    $aLLRESULTS |
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
    ConvertTo-Html -Head $CSS
)

$guidancePath = "C:\temp\guidancereservation_plan_from_advisor.html"
$guidanceHtml | Out-File -FilePath $guidancePath -Encoding UTF8
Write-Output "HTML guidance report has been saved to $guidancePath"
Invoke-Item -Path $guidancePath
