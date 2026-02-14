 <#
  'microsoft.graph','Az.Accounts', 'Az.Resources', 'Az.OperationalInsights','Azuread','az', 'Microsoft.Graph.Identity.DirectoryManagement'  | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
        # update-module $_ -force  -ErrorAction Ignore |out-null
         import-module -name $_ -force -ErrorAction Ignore |out-null
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
      #  install-module -name $_ -allowclobber -Force -ErrorAction Ignore|out-null 
        import-module -name $_ -force  -ErrorAction Ignore |out-null
    }
   #  Get-InstalledModule
}
  #>  

function get_query_results
{

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
    [string]$StorageContainer,        # (Optional) Blob container name for uploading results.
    [Parameter(Mandatory=$false)] [string[]] $subscriptionname
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
    #$res = Search-AzGraph -Query $kql -First 10000 -ErrorAction Stop
    $res = Search-AzGraph -Query $kql   -ErrorAction Stop
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

        $results += Run-LogAnalytics -workspaceId $wsId -kql $kql
    }
    elseif ($engine -eq "ResourceGraph") {
        $results += Run-ResourceGraph -kql $kql
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


 

catch {
    Write-Error $_.Exception.Message
 
}

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
  

 $context = connect-azaccount -Identity -tenantid e594a530-1ec9-4192-a8d4-a9111f8cffa7

set-azcontext -Subscription wolffentpsub


$ErrorActionPreference = 'silentlycontinue'

$outputDir = 'c:\temp'


        $QueryName = 'show all vnets with peering over x number'
        # Save results to CSV file (with timestamped filename based on query name)
        $safeName = ($QueryName -replace '[^0-9A-Za-z\-]', '')
        $outFile = Join-Path $OutputDir ("$safeName-$(Get-Date -Format yyyyMMdd_HHmmss).csv")
 $outFile       

 $subscriptions = get-azsubscription

 foreach($subscriptionname in ($subscriptions | select subscripitonname))
 {
  set-azcontext -subscription $subscriptionname
    foreach ($workspace in (Get-AzOperationalInsightsWorkspace | Select-Object CustomerId)) {
        $workspaceId = $workspace.CustomerId
        Write-Output "Running Log Analytics query against workspace $workspaceId ..."

 get_query_results -CatalogPath c:\temp\consolidatequeries.json `
                     -QueryName  $queryname `
                     -workspaceid $workspaceId  `
                     -subscriptionname wolffentpsub `
                     -OutputDir C:\temp

    }
}

