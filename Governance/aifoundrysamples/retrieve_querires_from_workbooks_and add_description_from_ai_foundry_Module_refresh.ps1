
<#
.SYNOPSIS
Generates an audit of Azure Monitor Deployment workbook queries across subscriptions and publishes the results to local files and Azure Storage.

.DESCRIPTION
This script authenticates to Azure using Managed Identity (preferred) and iterates through all accessible subscriptions. For each subscription, it:

1. Sets the subscription context.
2. Enumerates Workbooks (category 'workbook') and retrieves their serialized JSON content.
3. Extracts query-bearing items from workbook pages/visuals and builds a structured object per query with:
   - Type
   - Feature (decoded from the workbook JSON)
   - Version
   - Title
   - NoDataMessage
   - QueryType
   - ResourceType
   - CrossComponentResources
   - Query (the actual KQL/ARG text)
4. Calls a local module function `call_ai_foundry` to generate a human-readable Description for each query based on its Title and Query text.
   - Response text is HTML-decoded and hidden `<think>` blocks are stripped to yield clean output.
5. Produces three artifacts to `C:\temp\`:
   - `workbookname_queries.html` (a readable HTML report of unique queries)
   - `workbookname_queries.csv`  (a CSV export of unique queries)
   - `workbookname_queries.json` (the raw objects for downstream automation)
6. Switches to a designated subscription and resource group, ensures an Azure Storage account and container exist, and uploads the CSV (`workbookname_queries.csv`) to the container.

The script installs and imports required Az modules when needed, manages token freshness (logs out if cached REST token is expired), and is designed for non-interactive, automation-friendly use (Azure Automation, pipelines, VM/Host contexts) with Managed Identity.

.EXAMPLE
# Run end-to-end with Managed Identity
PS> .\Extract_Queries_From_Deployment_Workbooks.ps1

# Target a specific results subscription/storage (edit variables first)
PS> .\Extract_Queries_From_Deployment_Workbooks.ps1

.INPUTS
None. All inputs are hardcoded variables in the script:
- $Region
- $subscriptionselected
- $resourcegroupname
- $storageaccountname
- $storagecontainer
- $resultsfilename

.OUTPUTS
Local:
- C:\temp\workbookname_queries.html
- C:\temp\workbookname_queries.csv
- C:\temp\workbookname_queries.json

Azure Storage (in $subscriptionselected):
- Container: $storagecontainer
- Blob:     $resultsfilename (default: workbookname_queries.csv)

.REQUIREMENTS
- PowerShell 7.x or Windows PowerShell 5.1
- Az modules:
  - Az.Accounts
  - Az.Storage
  - Az.ResourceGraph
  - Az.Monitor and/or Az.ApplicationInsights (workbook cmdlets)
- Local module: `call_ai_foundry` (importable in session)
- Azure permissions:
  - Reader on target subscriptions (to read Workbooks)
  - Contributor on results RG (to create Storage Account if missing)
  - Storage Blob Data Contributor (to create container and upload blobs)
- Authentication:
  - Managed Identity (`Connect-AzAccount -Identity`) or Service Principal (non-interactive). Device auth is intentionally avoided.

.CONFIGURATION
Edit these variables as needed before running:
- $Region                  = "westus"
- $subscriptionselected    = "wolffentpsub"
- $resourcegroupname       = "wolffautomationrg"
- $storageaccountname      = "wolffautosa"
- $storagecontainer        = "graphqueriessamples"
- $resultsfilename         = "workbookname_queries.csv"

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
the use of or inability to use the sample and documentation, even if Microsoft has been advised
of the possibility of such damages.

.VERSION HISTORY
v1.0  - Initial release.
v1.1  - Expanded help, clarified module prerequisites, added AI-generated query descriptions,
        refined outputs (HTML/CSV/JSON), automated Storage container creation/upload.
v1.2  - Applied PSObject + Add-Member construction style end-to-end and added nested progress counters.
#>

# ---------- Authentication (Managed Identity preferred) ----------
Connect-AzAccount -Identity  # -Environment AzureUSGovernment (optional)

Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
try {
    $AzureLogin     = Get-AzSubscription
    $currentContext = Get-AzContext
    $token          = Get-AzAccessToken
    if ($token.ExpiresOn -lt (Get-Date)) {
        Write-Host "Cached token expired for REST auth. Disconnecting..." -ForegroundColor Yellow
        Disconnect-AzAccount | Out-Null
        throw "Token expired"
    }
}
catch {
    # Keep non-interactive; avoid device auth
    Write-Warning "Ensure Managed Identity or Service Principal is configured for non-interactive auth."
    # Example fallback (commented):
    # Connect-AzAccount -ServicePrincipal -Tenant <tenantId> -ApplicationId <appId> -CertificateThumbprint <thumb>
}

# ---------- Modules ----------
Import-Module call_ai_foundry -ErrorAction Stop
Install-Module -Name Az.ResourceGraph -AllowClobber -Force
Import-Module Az.ResourceGraph
Import-Module Az.Monitor -ErrorAction SilentlyContinue
Import-Module Az.ApplicationInsights -ErrorAction SilentlyContinue

# Optional helper if you want sentence/paragraph normalization
function Convert-GuidanceToCRLF {
    param([Parameter(Mandatory)][string]$Text)
    $lines = $Text -split "`r?`n"
    ($lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }) -join "`r`n`r`n"
}

# ---------- Working variables & paths ----------
$querylist = @()
$resultsfilename = 'workbookname_queries.csv'
$OutPath = 'C:\temp'
$null = New-Item -ItemType Directory -Path $OutPath -ErrorAction SilentlyContinue

# ---------- Enumerate subscriptions with progress ----------
$subscriptions = Get-AzSubscription
$subCount = $subscriptions.Count
$subIndex = 0

foreach ($subscription in $subscriptions) {
    $subIndex++
    Write-Progress -Id 1 `
        -Activity "Processing Subscriptions" `
        -Status "Subscription: $($subscription.Name)  [$subIndex/$subCount]" `
        -PercentComplete (($subIndex / $subCount) * 100)

    Set-AzContext -Subscription $subscription.Name | Out-Null

    # Get workbooks in subscription
    $workbooklist = Get-AzApplicationInsightsWorkbook -SubscriptionId $subscription.Id -Category 'workbook'
    $wbCount = ($workbooklist | Measure-Object).Count
    $wbIndex = 0

    foreach ($workbook in $workbooklist) {
        $wbIndex++
        Write-Progress -Id 2 -ParentId 1 `
            -Activity "Processing Workbooks" `
            -Status "$($workbook.DisplayName)  [$wbIndex/$wbCount]" `
            -PercentComplete (($wbIndex / $wbCount) * 100)

        $workbookname        = "$($workbook.Name)"
        $workbookdisplayname = "$($workbook.DisplayName)"

        # Fetch with content
        $workbookinfo = Get-AzApplicationInsightsWorkbook -Category 'workbook' -CanFetchContent |
                        Where-Object { $_.Name -eq $workbook.Name }

        if (-not $workbookinfo) { continue }

        $jsonresource = $workbookinfo.SerializedData | ConvertFrom-Json
        if (-not $jsonresource) { continue }

        # Extract query-bearing items
        $sourcequeries = $jsonresource.items | Select-Object -ExpandProperty content
        if (-not $sourcequeries) { continue }

        $queriesToProcess = $sourcequeries | Where-Object { $_.items.content.query -ne $null }
        $qCount = ($queriesToProcess | Measure-Object).Count
        $qIndex = 0

        foreach ($jsonitem in $queriesToProcess) {
            $qIndex++
            Write-Progress -Id 3 -ParentId 2 `
                -Activity "Extracting Queries" `
                -Status "Query group $qIndex of $qCount" `
                -PercentComplete (($qIndex / $qCount) * 100)

            foreach ($jsonitemcontent in ($jsonitem.items.content | Where-Object { $_.query -ne $null })) {

                $contenttypes = $jsonitem.items.type
                foreach ($contenttype in $contenttypes) {

                    # ---------- Build object using requested Add-Member style ----------
                    $jsoncontentobj = New-Object PSObject

                    $contentitems = $jsonitem.items.content
                    $Feature      = $contentitems.json -replace '{#',''

                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name Type                    -Value $contenttype
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name Feature                 -Value "$Feature"
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name Version                 -Value $jsonitemcontent.version
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name title                   -Value $jsonitemcontent.title
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name noDataMessage           -Value $jsonitemcontent.noDataMessage
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name queryType               -Value $jsonitemcontent.queryType
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name resourceType            -Value $jsonitemcontent.resourceType
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name crossComponentResources -Value $jsonitemcontent.crossComponentResources
                    $jsoncontentobj | Add-Member -MemberType NoteProperty -Name query                   -Value "$($jsonitemcontent.query)"

                    ###### get a brief description for the query (AI Foundry) ######
                    $response = & call_ai_foundry -prompt "provide a brief description for $($jsonitemcontent.title) based on $($jsonitemcontent.query)" *>&1

                    # Decode HTML entities and strip closing </think> block
                    $decoded = [System.Net.WebUtility]::HtmlDecode($response)
                    $pattern = '</think\s*>'
                    $match   = [System.Text.RegularExpressions.Regex]::Match($decoded, $pattern, 'IgnoreCase')

                    if ($match.Success) {
                        $startIndex = $match.Index + $match.Length
                        $afterThink = $decoded.Substring($startIndex)

                        # Trim and normalize CRLF
                        $result      = $afterThink.Trim()
                        $resultclean = ($result -replace "`r?`n", "`r`n")

                        # Sentence/paragraph normalization
                        if (Get-Command Convert-GuidanceToCRLF -ErrorAction SilentlyContinue) {
                            $guidanceText = Convert-GuidanceToCRLF -Text $resultclean
                        } else {
                            $lines = $resultclean -split "`r?`n"
                            $guidanceText = ($lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }) -join "`r`n`r`n"
                        }

                        $jsoncontentobj | Add-Member -MemberType NoteProperty -Name Description -Value "$guidanceText"
                    }
                    else {
                        # No <think> wrapper—still add a cleaned description
                        $jsoncontentobj | Add-Member -MemberType NoteProperty -Name Description -Value ($decoded.Trim())
                    }

                    # Append to collection
                    [array]$querylist += $jsoncontentobj
                }
            }
        }
    }
}

# Complete progress bars
Write-Progress -Id 1 -Completed
Write-Progress -Id 2 -Completed
Write-Progress -Id 3 -Completed -activity "Processing query description retrieval"

# ---------- Outputs ----------
# HTML (uses $CSS if defined)
try {
    (($querylist | Select-Object Version, title, noDataMessage, queryType, resourceType, crossComponentResources, query, Description |
        ConvertTo-Html -Head $CSS).Replace('Â Â','')) | Out-File (Join-Path $OutPath 'workbookname_queries.html')
    Invoke-Item (Join-Path $OutPath 'workbookname_queries.html')
} catch {
    Write-Warning "HTML report generation encountered an issue: $($_.Exception.Message)"
}

# CSV
$querylist | Select-Object Version, title, noDataMessage, queryType, resourceType, crossComponentResources, query, Description |
    Export-Csv (Join-Path $OutPath 'workbookname_queries.csv') -NoTypeInformation

# JSON
$querylist | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutPath 'workbookname_queries.json') -Encoding UTF8

# Results filename for upload
$resultsfilename = 'workbookname_queries.csv'

# ---------- Storage / Upload ----------
$Region               = "westus"
$subscriptionselected = "wolffentpsub"
$resourcegroupname    = "wolffautomationrg"
$storageaccountname   = "wolffautosa"
$storagecontainer     = "graphqueriessamples"

# Switch to results subscription
$subscriptioninfo = Get-AzSubscription -SubscriptionName $subscriptionselected
$TenantID         = $subscriptioninfo | Select-Object -ExpandProperty TenantId

Set-AzContext -Subscription $subscriptioninfo.Name -Tenant $TenantID | Out-Null

# Create storage account if missing
try {
    if (-not (Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname)) {
        Write-Host "Storage Account does not exist. Creating: $storageaccountname" -ForegroundColor Yellow
        New-AzStorageAccount -ResourceGroupName $resourcegroupname `
                             -Name $storageaccountname `
                             -Location $Region `
                             -AccessTier Hot `
                             -SkuName Standard_LRS `
                             -Kind BlobStorage `
                             -Tag @{ owner = "Jerry Wolff"; purpose = "Az Automation storage write" } `
                             -Verbose -ErrorAction SilentlyContinue | Out-Null

        Get-AzStorageAccount -Name $storageaccountname -ResourceGroupName $resourcegroupname -Verbose | Out-Null
    }
}
catch {
    Write-Debug "Storage Account already exists. Skipping creation of $storageaccountname"
}

# Get key & context
$StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname -StorageAccountName $storageaccountname).Value | Select-Object -First 1
$destContext = New-AzStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $StorageKey

# Ensure container
try {
    if (-not (Get-AzStorageContainer -Name $storagecontainer -Context $destContext)) {
        New-AzStorageContainer -Name $storagecontainer -Context $destContext -ErrorAction SilentlyContinue | Out-Null
    }
} catch {
    Write-Warning "$storagecontainer container already exists"
}

# Upload CSV
Set-AzStorageBlobContent -Container $storagecontainer `
                         -Blob $resultsfilename `
                         -File (Join-Path $OutPath $resultsfilename) `
                         -Context $destContext `
                         -Force
