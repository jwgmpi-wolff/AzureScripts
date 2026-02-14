
<#
.SYNOPSIS
Run a query from a catalog (JSON/CSV/blob) via Log Analytics or Resource Graph and save results.

.DESCRIPTION
This script loads an indexed catalog of Kusto queries (from a local JSON/CSV file or a remote blob URL), 
finds a query by DisplayName or QueryId, determines whether it is a Log Analytics query or Azure Resource Graph query, 
runs it accordingly, and saves the results as a CSV (optionally uploading to Azure Blob Storage). 
It handles authentication (using Managed Identity if available, otherwise interactive login or service principal), 
and prints a preview of the results.

.PARAMETER CatalogPath
Path or URL (with SAS token if needed) to the catalog file (JSON or CSV) containing queries. 
If a URL is provided, the file is downloaded to a temp location first.

.PARAMETER QueryName
The DisplayName or unique QueryId of the query to run (case-insensitive). If not an exact match, a partial (contains) match will be attempted.

.PARAMETER WorkspaceId
(Optional) The Log Analytics Workspace ID (GUID). Required if the selected query is for Log Analytics and the workspace is not specified in the catalog.

.PARAMETER OutputDir
(Optional) Local directory to save the CSV results. Defaults to the system TEMP directory.

.PARAMETER StorageAccountName
(Optional) Name of Azure Storage account to upload the CSV results. If provided, must also set StorageResourceGroup and StorageContainer.

.PARAMETER StorageResourceGroup
(Optional) Resource group of the Storage account for uploading results.

.PARAMETER StorageContainer
(Optional) Name of the blob container in the Storage account to upload the results file.

.EXAMPLE
Run-CatalogQuery.ps1 -CatalogPath "C:\temp\consolidatequeries.json" -QueryName "underutilized_resources" -OutputDir "C:\temp"

.EXAMPLE
Run-CatalogQuery.ps1 -CatalogPath "https://<storage-account>.blob.core.windows.net/catalog/consolidated_queries.json?<SAS>" `
                     -QueryName "underutilized_resources" `
                     -StorageAccountName "<StorageAcctName>" -StorageResourceGroup "<ResourceGroup>" -StorageContainer "results"

.EXAMPLE
Run-CatalogQuery.ps1 -CatalogPath "C:\temp\resourcegraphqueries.json" -QueryName "microsoft_compute_disks" -OutputDir "C:\temp"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$CatalogPath,            # Local file path or Blob URL (with SAS) of the catalog (JSON or CSV).
    [Parameter(Mandatory=$true)]
    [string]$QueryName,              # DisplayName or QueryId of the query to run (case-insensitive).
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceId,            # (Optional) Log Analytics workspace ID (GUID), if not specified in catalog.
    [Parameter(Mandatory=$true)]
    [string]$OutputDir = $env:TEMP,  # (Optional) Directory for output CSV (default: system TEMP).
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName,     # (Optional) Storage account name for uploading results.
    [Parameter(Mandatory=$false)]
    [string]$StorageResourceGroup,   # (Optional) Resource group of the storage account.
    [Parameter(Mandatory=$false)]
    [string]$StorageContainer        # (Optional) Blob container name for uploading results.
)

# Ensure required Az PowerShell modules are present (Accounts, OperationalInsights, ResourceGraph, Storage):
# (Uncomment the following lines if modules are not already installed/imported in your environment.)
# Install-Module Az -Scope CurrentUser -Force              # Install Az module (includes all sub-modules)
# Import-Module Az.Accounts, Az.OperationalInsights, Az.ResourceGraph, Az.Storage

# Function to load the query catalog from JSON/CSV or a URL
function Read-Catalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $path
    )
      
        Write-Output "verifying catalog from   $path ..."
         
      
     write-output "$path"  
   
     $text = Get-Content   -Path $path

    # Try JSON first
    try {
        $j = $text | ConvertFrom-Json -ErrorAction Stop
        if ($j -is [System.Array]) { return $j } else { return @($j) }
    }
    catch {
        # If JSON parse fails, attempt CSV
        try {
            return Import-Csv -Path $path
        }
        catch {
            throw "Catalog is not valid JSON or CSV: $path"
        }
    }
}

# Function to find a query in the catalog by name or ID (case-insensitive)
function Find-QueryInCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [array] $catalog,
        [Parameter(Mandatory=$true)] [string] $name
    )
    $nameLower = $name.ToLower()
    # First try exact match on DisplayName, Name, or QueryId
    $match = $catalog | Where-Object {
        ($_.DisplayName -and $_.DisplayName.ToLower() -eq $nameLower) -or
        ($_.Name        -and $_.Name.ToLower()        -eq $nameLower) -or
        ($_.QueryId     -and $_.QueryId.ToLower()     -eq $nameLower)
    } | Select-Object -First 1
    if ($match) { return $match }
    # Fallback: partial (contains) match on DisplayName or Name
    $match = $catalog | Where-Object {
        ($_.DisplayName -and $_.DisplayName.ToLower().Contains($nameLower)) -or
        ($_.Name        -and $_.Name.ToLower().Contains($nameLower))
    } | Select-Object -First 1
    return $match
}

# Function to determine if a query should run on Log Analytics vs Resource Graph
function Determine-Engine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $row   # one query record from the catalog
    )
    # Identify the KQL text field (catalog might use different property names)
    $kql = ($row.Kql -or $row.QueryBody -or $row.Query -or $row.QueryText) -as [string]
    if (-not $kql) {
        return @{ Engine = "Unknown"; Kql = "" }
    }
    $trim = $kql.TrimStart()
    # Check 'Source' field explicitly, if present
    if ($row.PSObject.Properties.Name -contains 'Source' -and $row.Source -match 'ResourceGraph') {
        return @{ Engine = "ResourceGraph"; Kql = $kql }
    }
    # Heuristic: If query text starts with 'resources |', treat as Resource Graph
    if ($trim -match '^\s*resources\s*\|') {
        return @{ Engine = "ResourceGraph"; Kql = $kql }
    }
    # Heuristic: If query references known Log Analytics tables or schema, treat as Log Analytics
    if ($kql -match 'AzureMetrics|InsightsMetrics|Perf|Heartbeat|SigninLogs|StorageBlobLogs|AzureNetworkAnalytics_CL|Event|AuditLogs') {
        return @{ Engine = "LogAnalytics"; Kql = $kql }
    }
    # Default to Log Analytics if uncertain
    return @{ Engine = "LogAnalytics"; Kql = $kql }
}

# Function to run a Log Analytics query (returns up to 10,000 results by default)
function Run-LogAnalytics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $workspaceId,
        [Parameter(Mandatory=$true)] [string] $kql
    )
    if (-not $workspaceId) {
        throw "WorkspaceId is required for Log Analytics query execution."
    }
    Write-Output "Running Log Analytics query against workspace $workspaceId ..."
    $res = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $kql -ErrorAction Stop
    return $res.Results  # Return the results dataset
}

# Function to run an Azure Resource Graph query
function Run-ResourceGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $kql
    )
    Write-Output "Running Resource Graph query..."
    $res = Search-AzGraph -Query $kql -First 10000 -ErrorAction Stop
    return $res
}

# Function to save results to a CSV file

function Save-ResultsToCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $objects,
        [Parameter(Mandatory=$true)] [string] $outPath,
        [Parameter(Mandatory=$false)] [string[]] $fields
    )

    # Ensure output directory exists
    $dir = Split-Path $outPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # Export using dynamic fields if provided
    if ($fields) {
    $objects | Select-Object -Property $fields
        $objects | Select-Object -Property $fields | Export-Csv -Path $outPath -NoTypeInformation
    } else {
    $objects | Select-Object -Property *
        $objects | Select-Object -Property * | Export-Csv -Path $outPath -NoTypeInformation
    }

    return $outPath
}


# Function to upload a file to Azure Blob Storage (requires appropriate RBAC or credentials)
function Upload-ToStorage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string] $filePath,
        [Parameter(Mandatory=$true)] [string] $accountName,
        [Parameter(Mandatory=$true)] [string] $rg,
        [Parameter(Mandatory=$true)] [string] $container
    )
    # Get storage account context (requires Azure login with access to the storage account)
    $sa = Get-AzStorageAccount -Name $accountName -ResourceGroupName $rg -ErrorAction Stop
    $ctx = $sa.Context
    $blobName = Split-Path $filePath -Leaf
    Set-AzStorageBlobContent -File $filePath -Container $container -Blob $blobName -Context $ctx -Force | Out-Null
    $url = "https://$($accountName).blob.core.windows.net/$($container)/$blobName"
    return $url
}

# --- Main Execution ---
try {
    # Authenticate with Azure (try Managed Identity first, fall back to interactive/device login or SPN if needed)
    try {
        Connect-AzAccount -Identity -ErrorAction Stop
        Write-Output "Authenticated with Managed Identity."
    }
    catch {
        Write-Warning "Managed identity login failed; falling back to interactive or service principal login..."
        Connect-AzAccount -ErrorAction Stop
    }

    # Load and parse the catalog
    $catalog = Read-Catalog -path $CatalogPath
    Write-Output ("Catalog items loaded: {0}" -f $catalog.Count)

    # Find the requested query in the catalog
    $row = Find-QueryInCatalog -catalog $catalog -name $QueryName
    if (-not $row) { throw "Query '$QueryName' not found in the catalog." }

    # Identify query details (some catalogs might use different property names)
    $meta = @{
        DisplayName = ($row.DisplayName -or $row.Name);
        Source      = ($row.Source -or $null);
        Kql         = ($row.Kql -or $row.QueryBody -or $row.Query -or $row.QueryText)
    }
    Write-Output ("Selected query: {0} (Source: {1})" -f $meta.DisplayName, ($meta.Source -or "Unknown"))

    # Determine which engine to use (Log Analytics vs Resource Graph)
    $engineInfo = Determine-Engine -row $row
    $engine = $engineInfo.Engine
    $kql    = $row.QueryBody


    if (-not $kql -or $kql.Trim().Length -eq 0) { throw "No KQL query text found for '$QueryName'." }

    # Execute the query using the appropriate engine
    if ($engine -eq "LogAnalytics") {
        # Determine workspace ID: use parameter, or catalog field, or default to first workspace in subscription
        $wsId = $WorkspaceId
        if (-not $wsId) {
            if ($row.PSObject.Properties.Name -contains 'WorkspaceId' -and $row.WorkspaceId) {
                $wsId = $row.WorkspaceId 
            }
            elseif ($row.PSObject.Properties.Name -contains 'Workspace' -and $row.Workspace) {
                $wsId = $row.Workspace
            }
        }
        if (-not $wsId) {
            $w = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($w) { 
                $wsId = $w.CustomerId 
                Write-Output "No workspace specified — using first workspace found: $($w.Name)"
            }
        }
        if (-not $wsId) { throw "Log Analytics workspace ID not provided. Use -WorkspaceId or ensure the catalog entry includes it." }

        $results = Run-LogAnalytics -workspaceId $wsId -kql $kql
    }
    elseif ($engine -eq "ResourceGraph") {
        $results = Run-ResourceGraph -kql $kql
    }
    else {
        throw "Could not determine query engine (Log Analytics vs ResourceGraph)."
    }

    # Handle empty result set
    if (-not $results -or $results.Count -eq 0) {
        Write-Output "Query executed successfully, but returned **no rows**."
        exit 0
    }


        # Determine dynamic property list from the first object in $results
        $propertyList = @()
        if ($results -and $results.Count -gt 0) {
            $propertyList = $results[1] | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
        }

        # Save results to CSV file (with timestamped filename based on query name)
        $safeName = ($QueryName -replace '[^0-9A-Za-z\-]', '')
        $outFile = Join-Path $OutputDir ("$safeName-$(Get-Date -Format yyyyMMdd_HHmmss).csv")
    
    
            # Export using dynamic fields if provided
            if ($propertyList) {
            $results | Select-Object -Property $propertyList
                $results | Select-Object -Property $propertyList | Export-Csv -Path $outFile -NoTypeInformation -Append
            } else {
            $results | Select-Object -Property *
                $results | Select-Object -Property * | Export-Csv -Path $outFile -NoTypeInformation -Append
            }


       # Save-ResultsToCsv -objects $results -outPath $outFile -fields $propertyList
        Write-Output "Saved results to: $outFile"


    # If storage upload parameters were provided, upload the CSV to Azure Blob Storage
    if ($StorageAccountName -and $StorageResourceGroup -and $StorageContainer) {
        $blobUrl = Upload-ToStorage -filePath $outFile -accountName $StorageAccountName -rg $StorageResourceGroup -container $StorageContainer
        Write-Output "Uploaded results to: $blobUrl"
    }
 
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}









