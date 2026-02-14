
<#
.SYNOPSIS
Generates an audit of Azure Monitor Deployment workbook queries across subscriptions and publishes the results to local files and Azure Storage.

.DESCRIPTION
This script performs an end-to-end audit of Azure Monitor Deployment Workbooks and their queries:

- **Authentication**: Uses Managed Identity (preferred) or Service Principal for non-interactive login.
- **Subscription Processing**:
    * Iterates through all accessible subscriptions.
    * Sets the subscription context and enumerates Workbooks (category: 'workbook').
- **Query Extraction**:
    * Retrieves workbook JSON content.
    * Extracts query-bearing items (KQL/ARG) and builds structured objects with metadata:
        - Type, Feature, Version, Title, QueryType, ResourceType, CrossComponentResources, Query.
- **AI-Assisted Description**:
    * Calls local module `call_ai_foundry` to generate human-readable descriptions for each query.
    * Cleans and normalizes AI output for readability.
- **Output Generation**:
    * Creates three local artifacts in `C:\temp\`:
        - HTML report (`workbookname_queries.html`)
        - CSV export (`workbookname_queries.csv`)
        - JSON file (`workbookname_queries.json`)
- **Azure Storage Upload**:
    * Switches to a designated subscription/resource group.
    * Ensures Storage Account and container exist.
    * Uploads the CSV file to the specified container.
- **Automation-Friendly**:
    * Handles Az module installation and token freshness.
    * Designed for pipelines, Azure Automation, or VM contexts without interactive prompts.
.EXAMPLE
# Run the script end-to-end using Managed Identity (recommended for automation)
PS> .\Extract_Queries_From_Deployment_Workbooks.ps1

# Run the script and publish results to a specific subscription and storage account
# (Ensure variables such as $subscriptionselected, $resourcegroupname, and $storageaccountname are updated)
PS> .\Extract_Queries_From_Deployment_Workbooks.ps1
.INPUTS
None. The script uses predefined variables for configuration:

- **$Region**                – Azure region for resource deployment (e.g., "westus")
- **$subscriptionselected**  – Subscription name for storing results
- **$resourcegroupname**     – Resource group for the Storage Account
- **$storageaccountname**    – Name of the Storage Account
- **$storagecontainer**      – Name of the blob container
- **$resultsfilename**       – Output CSV filename (default: "workbookname_queries.csv")


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

import-module call_ai_foundry_ext -force -verbose

Connect-AzAccount -Identity  # -Environment AzureUSGovernment (optional)

# variables ##############
#### get AI keys and endpoints from Azure keyvault
 
 $vaultName     = "wolffmlkv"
$resourceGroup = "wolffmlrg"
$spnName       = "wolffaifoundryspn"

 Update-AzKeyVault -VaultName $vaultName -ResourceGroupName $resourceGroup -PublicNetworkAccess Enabled | Out-Null
Update-AzKeyVaultNetworkRuleSet -VaultName $vaultName -ResourceGroupName $resourceGroup -Bypass AzureServices -DefaultAction Allow | Out-Null

Write-Host "Key Vault temporarily opened (PNA Enabled + AzureServices bypass). Proceeding to read secrets." -ForegroundColor Yellow
 
  $endpointuri =   Get-AzKeyVaultSecret -VaultName $vaultName -Name "wolffaipoc2-resource-endpoint" -AsPlainText
 $endpointkeyvalue =   Get-AzKeyVaultSecret -VaultName $vaultName -Name "wolffaipoc2-resource-key1" -AsPlainText


##############################################


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


                    $response = & call_ai_foundry_ext -ApiKey $endpointkeyvalue `
                     -prompt "provide a brief description for $($jsonitemcontent.title) based on $($jsonitemcontent.query)"  `
                     -Endpoint ("$endpointuri"+'models') *>&1

  #$response
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
Write-Progress -Id 3 -Completed -Activity "processing dewscriptions"


     $CSS = @"
<Title>All queries Report:$(Get-Date -Format 'dd MMMM yyyy' )</Title>
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







# ---------- Outputs ----------
# HTML (uses $CSS if defined)
try {
    (($querylist | Select-Object Version, title, noDataMessage, queryType, resourceType,   query, Description -unique   |
        ConvertTo-Html -Head $CSS).Replace('Â Â','')) | Out-File (Join-Path $OutPath 'workbookname_queries.html')
    Invoke-Item (Join-Path $OutPath 'workbookname_queries.html')
} catch {
    Write-Warning "HTML report generation encountered an issue: $($_.Exception.Message)"
}

# CSV
$querylist | Select-Object Version, title, noDataMessage, queryType, resourceType,   query, Description -Unique |
    Export-Csv (Join-Path $OutPath 'workbookname_queries.csv') -NoTypeInformation

# JSON
$querylist| Select-Object Version, title, noDataMessage, queryType, resourceType,   query, Description -Unique | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutPath 'workbookname_queries.json') -Encoding UTF8

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

Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowBlobPublicAccess $true -AllowSharedKeyAccess $true  -force


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
