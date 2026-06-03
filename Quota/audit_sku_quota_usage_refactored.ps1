<#
.SYNOPSIS
    Audits Azure subscription quotas and usage across regions with HTML formatted reports.

.DESCRIPTION
    This script connects to Azure subscriptions and audits VM quota usage across all regions.
    It generates detailed HTML reports with color-coded usage percentages and CSV exports.

.PARAMETER SubscriptionNames
    Specific subscription names to audit. If not specified, audits all accessible subscriptions.

.PARAMETER OutputPath
    Directory path for output files. Default: 'c:\temp'

.PARAMETER OutputFormat
    Format for output: 'HTML', 'CSV', or 'Both'. Default: 'Both'

.PARAMETER HighThreshold
    Percentage threshold for high usage warning. Default: 80

.PARAMETER CriticalThreshold
    Percentage threshold for critical usage warning. Default: 90

.PARAMETER IncludeUnused
    Include unused resources in the report. Default: $false

.EXAMPLE
    .\audit_sku_quota_usage_refactored.ps1 -OutputPath 'C:\Reports' -OutputFormat 'HTML'

.EXAMPLE
    .\audit_sku_quota_usage_refactored.ps1 -SubscriptionNames 'ProdsSubscription' -HighThreshold 75

.NOTES
    Requires: Az.Accounts, Az.Compute modules
    Author: Azure Automation
    Date: May 2026
#>

[CmdletBinding()]
param(
    [string[]]$SubscriptionNames,
    
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$OutputPath = 'c:\temp',
    
    [ValidateSet('HTML', 'CSV', 'Both')]
    [string]$OutputFormat = 'Both',
    
    [ValidateRange(0, 100)]
    [int]$HighThreshold = 80,
    
    [ValidateRange(0, 100)]
    [int]$CriticalThreshold = 90,
    
    [switch]$IncludeUnused
)

# ============================================================================
# SCRIPT CONFIGURATION AND INITIALIZATION
# ============================================================================

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$scriptVersion = '2.0'
$reportDate = Get-Date -Format 'dd MMMM yyyy'
$reportDateTime = Get-Date -Format 'yyyy-MM-dd_HHmmss'

# Suppress Azure PowerShell breaking change warnings
$null = $env:SuppressAzurePowerShellBreakingChangeWarnings = 'true'

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-LogInfo {
    param([string]$Message)
    Write-Information -MessageData "$(Get-Date -Format 'HH:mm:ss') [INFO] $Message"
}

function Write-LogError {
    param([string]$Message)
    Write-Error -Message "$(Get-Date -Format 'HH:mm:ss') [ERROR] $Message"
}

function Write-LogWarning {
    param([string]$Message)
    Write-Warning -Message "$(Get-Date -Format 'HH:mm:ss') [WARNING] $Message"
}

function Write-Banner {
    Write-Host ""
    Write-Host " _                _          _         ____    ____       " -ForegroundColor Green
    Write-Host " \\      /\      // _____   | |       |____|  |____|      " -ForegroundColor Yellow
    Write-Host "  \\    //\\    // |  _  |  | |       | |__   | |__       " -ForegroundColor Red
    Write-Host "   \\  //  \\  //  | | | |  | |       | ___|  | ___|      " -ForegroundColor Cyan
    Write-Host "    \\//    \\//   | |_| |  | |____   | |     | |         " -ForegroundColor DarkCyan
    Write-Host "     \/      \/    |_____|  |______|  |_|     |_|         " -ForegroundColor Magenta
    Write-Host ""
    Write-Host " Azure Quota Usage Audit Tool v$scriptVersion" -ForegroundColor Green
    Write-Host " This script audits Azure quota usage by region and subscription" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# AZURE MANAGED IDENTITY CONNECTION
# ============================================================================

function Connect-AzureWithManagedIdentity {
    try {
        Write-LogInfo "Authenticating with managed identity..."
        
        # Connect using managed identity (works in Azure Automation, Azure Functions, etc.)
        # When running locally with Azure CLI authenticated, this auto-uses those credentials
        Connect-AzAccount -Identity -ErrorAction SilentlyContinue | Out-Null
        
        # If managed identity failed, try default Azure CLI context
        if (-not $?) {
            Write-LogInfo "Managed identity not available, using default Azure context..."
            # Get current context - assumes user is already authenticated via az cli
            $context = Get-AzContext -ErrorAction Stop
            if (-not $context) {
                throw "Not authenticated. Please authenticate using 'Connect-AzAccount' or 'az login' first"
            }
        }
        
        Write-LogInfo "Successfully authenticated to Azure"
    }
    catch {
        Write-LogError "Failed to authenticate to Azure: $_"
        throw
    }
}

# ============================================================================
# QUOTA DATA COLLECTION FUNCTION
# ============================================================================

function Get-QuotaUsageData {
    param(
        [string[]]$SubscriptionNames,
        [int]$HighThreshold,
        [int]$CriticalThreshold
    )
    
    $usageSummary = @()
    $subscriptions = $null
    
    try {
        # Get subscriptions
        $allSubscriptions = Get-AzSubscription -ErrorAction Stop
        
        if ($SubscriptionNames) {
            $subscriptions = $allSubscriptions | Where-Object { $_.Name -in $SubscriptionNames }
            if ($subscriptions.Count -eq 0) {
                Write-LogWarning "No subscriptions found matching: $($SubscriptionNames -join ', ')"
                return $null
            }
        }
        else {
            $subscriptions = $allSubscriptions
        }
        
        Write-LogInfo "Found $($subscriptions.Count) subscription(s) to audit"
        
        # Get all available regions
        $regions = Get-AzLocation -ErrorAction Stop
        Write-LogInfo "Found $($regions.Count) region(s) to check"
        
        # Process each subscription
        $subNumber = 0
        foreach ($subscription in $subscriptions) {
            $subNumber++
            $subName = $subscription.Name
            $subId = $subscription.Id
            
            Write-LogInfo "[$subNumber/$($subscriptions.Count)] Processing subscription: $subName"
            
            # Set subscription context
            $null = Set-AzContext -SubscriptionId $subId -ErrorAction Stop
            $null = Get-AzAccessToken -TenantId $subscription.TenantId -ErrorAction Stop
            
            # Process each region
            $regionNumber = 0
            foreach ($location in $regions) {
                $regionNumber++
                $locationName = $location.Location
                
                # Get quota usage for this region
                $regionQuotas = Get-AzVMUsage -Location $locationName -ErrorAction SilentlyContinue
                
                if ($null -eq $regionQuotas) {
                    continue
                }
                
                # Process each quota item
                foreach ($quotaItem in $regionQuotas) {
                    $usedCount = [int]$quotaItem.CurrentValue
                    $quota = [int]$quotaItem.Limit
                    
                    # Skip unused resources if not requested
                    if (-not $IncludeUnused -and $usedCount -eq 0) {
                        continue
                    }
                    
                    # Calculate percentage
                    $percentageUsed = if ($quota -gt 0) {
                        [math]::Round(($usedCount / $quota) * 100, 2)
                    }
                    else {
                        0
                    }
                    
                    # Determine status based on thresholds
                    $status = switch ($percentageUsed) {
                        { $_ -ge $CriticalThreshold } { 'Critical' }
                        { $_ -ge $HighThreshold } { 'High' }
                        { $_ -gt 0 } { 'Normal' }
                        default { 'Unused' }
                    }
                    
                    # Create quota object
                    $quotaObject = [PSCustomObject]@{
                        'Subscription'              = $subName
                        'SubscriptionId'            = $subId
                        'Region'                    = $locationName
                        'ResourceType'              = $quotaItem.Name.Value
                        'ResourceLocalizedName'     = $quotaItem.Name.LocalizedValue
                        'CurrentCount'              = $usedCount
                        'Limit'                     = $quota
                        'PercentageUsed'            = $percentageUsed
                        'RemainingCapacity'         = $quota - $usedCount
                        'Status'                    = $status
                        'CollectionTime'            = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    }
                    
                    $usageSummary += $quotaObject
                }
            }
            
            Write-Progress -Activity "Processing Regions" -Status "$regionNumber/$($regions.Count)" -PercentComplete (($regionNumber / $regions.Count) * 100)
        }
        
        Write-Progress -Activity "Processing Regions" -Completed
        
        return $usageSummary
    }
    catch {
        Write-LogError "Failed to collect quota usage data: $_"
        throw
    }
}

# ============================================================================
# HTML REPORT GENERATION FUNCTION
# ============================================================================

function New-HTMLReport {
    param(
        [PSCustomObject[]]$QuotaData,
        [string]$OutputPath,
        [string]$Title,
        [switch]$IncludeAllResources
    )
    
    if ($null -eq $QuotaData -or $QuotaData.Count -eq 0) {
        Write-LogWarning "No quota data to generate report"
        return $null
    }
    
    # Filter data if needed
    $filteredData = if ($IncludeAllResources) {
        $QuotaData
    }
    else {
        $QuotaData | Where-Object { $_.CurrentCount -gt 0 }
    }
    
    # Generate filename
    $fileName = if ($IncludeAllResources) {
        "$OutputPath\quota_audit_all_resources_$reportDateTime.html"
    }
    else {
        "$OutputPath\quota_audit_active_resources_$reportDateTime.html"
    }
    
    # CSS styling
    $cssContent = @"
<style>
    * {
        font-family: Segoe UI, Arial, sans-serif;
        margin: 0;
        padding: 0;
    }
    
    body {
        background-color: #f5f5f5;
        padding: 20px;
    }
    
    .container {
        max-width: 1400px;
        margin: 0 auto;
        background-color: white;
        padding: 30px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    
    h1 {
        color: #0078d4;
        border-bottom: 3px solid #0078d4;
        padding-bottom: 10px;
        margin-bottom: 10px;
    }
    
    h2 {
        color: #106ebe;
        margin-top: 30px;
        margin-bottom: 15px;
        font-size: 16px;
    }
    
    .summary {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 20px;
        margin: 20px 0;
    }
    
    .summary-box {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 20px;
        border-radius: 8px;
        text-align: center;
    }
    
    .summary-box.critical {
        background: linear-gradient(135deg, #f93b1d 0%, #ea1e63 100%);
    }
    
    .summary-box.high {
        background: linear-gradient(135deg, #fa7343 0%, #f1576c 100%);
    }
    
    .summary-box.normal {
        background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
    }
    
    .summary-box h3 {
        font-size: 28px;
        margin-bottom: 5px;
    }
    
    .summary-box p {
        font-size: 12px;
        opacity: 0.9;
    }
    
    table {
        width: 100%;
        border-collapse: collapse;
        margin: 20px 0;
    }
    
    th {
        background-color: #0078d4;
        color: white;
        padding: 12px;
        text-align: left;
        font-weight: 600;
        border: 1px solid #ddd;
    }
    
    td {
        padding: 10px 12px;
        border: 1px solid #ddd;
        font-size: 12px;
    }
    
    tr:nth-child(even) {
        background-color: #f9f9f9;
    }
    
    tr:hover {
        background-color: #f0f0f0;
    }
    
    .status-critical {
        background-color: #fff4ce;
        color: #856404;
        padding: 4px 8px;
        border-radius: 4px;
        font-weight: 600;
    }
    
    .status-high {
        background-color: #fcf8e3;
        color: #8a6d3b;
        padding: 4px 8px;
        border-radius: 4px;
        font-weight: 600;
    }
    
    .status-normal {
        background-color: #d4edda;
        color: #155724;
        padding: 4px 8px;
        border-radius: 4px;
    }
    
    .status-unused {
        background-color: #e2e3e5;
        color: #383d41;
        padding: 4px 8px;
        border-radius: 4px;
    }
    
    .percentage-bar {
        width: 100%;
        height: 20px;
        background-color: #e0e0e0;
        border-radius: 4px;
        overflow: hidden;
        position: relative;
    }
    
    .percentage-fill {
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 10px;
        font-weight: bold;
    }
    
    .percentage-fill.normal {
        background-color: #6ba3d6;
    }
    
    .percentage-fill.high {
        background-color: #f1576c;
    }
    
    .percentage-fill.critical {
        background-color: #ea1e63;
    }
    
    .footer {
        margin-top: 40px;
        padding-top: 20px;
        border-top: 1px solid #ddd;
        color: #666;
        font-size: 11px;
    }
    
    .legend {
        display: flex;
        gap: 30px;
        margin: 20px 0;
        flex-wrap: wrap;
    }
    
    .legend-item {
        display: flex;
        align-items: center;
        gap: 10px;
    }
    
    .legend-box {
        width: 20px;
        height: 20px;
        border-radius: 3px;
    }
</style>
"@
    
    # Calculate summary statistics
    $criticalCount = ($filteredData | Where-Object { $_.Status -eq 'Critical' }).Count
    $highCount = ($filteredData | Where-Object { $_.Status -eq 'High' }).Count
    $normalCount = ($filteredData | Where-Object { $_.Status -eq 'Normal' }).Count
    $unusedCount = ($filteredData | Where-Object { $_.Status -eq 'Unused' }).Count
    $totalResources = $filteredData.Count
    
    # Build HTML header
    $htmlHeader = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure Quota Usage Audit Report - $reportDate</title>
    $cssContent
</head>
<body>
    <div class="container">
        <h1>Azure Quota Usage Audit Report</h1>
        <p>Generated: <strong>$reportDate</strong></p>
        
        <div class="legend">
            <div class="legend-item">
                <div class="legend-box" style="background-color: #ea1e63;"></div>
                <span>Critical (&geq; $CriticalThreshold%)</span>
            </div>
            <div class="legend-item">
                <div class="legend-box" style="background-color: #f1576c;"></div>
                <span>High (&geq; $HighThreshold%)</span>
            </div>
            <div class="legend-item">
                <div class="legend-box" style="background-color: #6ba3d6;"></div>
                <span>Normal (0% - $($HighThreshold - 1)%)</span>
            </div>
            <div class="legend-item">
                <div class="legend-box" style="background-color: #e2e3e5;"></div>
                <span>Unused (0%)</span>
            </div>
        </div>
        
        <h2>Summary Statistics</h2>
        <div class="summary">
            <div class="summary-box critical">
                <h3>$criticalCount</h3>
                <p>Critical (≥ $CriticalThreshold%)</p>
            </div>
            <div class="summary-box high">
                <h3>$highCount</h3>
                <p>High (≥ $HighThreshold%)</p>
            </div>
            <div class="summary-box normal">
                <h3>$normalCount</h3>
                <p>Normal</p>
            </div>
            <div class="summary-box">
                <h3>$totalResources</h3>
                <p>Total Resources</p>
            </div>
        </div>
        
        <h2>Detailed Usage Report</h2>
        <table>
            <thead>
                <tr>
                    <th>Subscription</th>
                    <th>Region</th>
                    <th>Resource Type</th>
                    <th>Current Usage</th>
                    <th>Limit</th>
                    <th>Remaining</th>
                    <th>Usage %</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
"@
    
    # Build table rows
    $htmlRows = @()
    foreach ($item in $filteredData | Sort-Object -Property Subscription, Region, ResourceType) {
        $statusClass = "status-$($item.Status.ToLower())"
        $fillClass = switch ($item.Status) {
            'Critical' { 'critical' }
            'High' { 'high' }
            default { 'normal' }
        }
        
        $percentageDisplay = "{0:N2}" -f $item.PercentageUsed
        $barWidth = [math]::Min($item.PercentageUsed, 100)
        
        $row = @"
                <tr>
                    <td>$($item.Subscription)</td>
                    <td>$($item.Region)</td>
                    <td>$($item.ResourceLocalizedName)<br><small style="color: #999;">($($item.ResourceType))</small></td>
                    <td style="text-align: center;">$($item.CurrentCount)</td>
                    <td style="text-align: center;">$($item.Limit)</td>
                    <td style="text-align: center;">$($item.RemainingCapacity)</td>
                    <td>
                        <div class="percentage-bar">
                            <div class="percentage-fill $fillClass" style="width: ${barWidth}%;">$percentageDisplay%</div>
                        </div>
                    </td>
                    <td><span class="$statusClass">$($item.Status)</span></td>
                </tr>
"@
        $htmlRows += $row
    }
    
    # Build HTML footer
    $htmlFooter = @"
            </tbody>
        </table>
        
        <div class="footer">
            <p><strong>Report Details:</strong></p>
            <ul>
                <li>Total Resources Analyzed: $totalResources</li>
                <li>Critical Status (≥ $CriticalThreshold%): $criticalCount</li>
                <li>High Status (≥ $HighThreshold%): $highCount</li>
                <li>Normal Status: $normalCount</li>
                <li>Unused Resources: $unusedCount</li>
                <li>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</li>
            </ul>
        </div>
    </div>
</body>
</html>
"@
    
    # Combine all parts and save
    $htmlContent = $htmlHeader + ($htmlRows -join "`n") + $htmlFooter
    $htmlContent | Out-File -FilePath $fileName -Encoding UTF8 -Force
    
    Write-LogInfo "HTML report generated: $fileName"
    return $fileName
}

# ============================================================================
# CSV EXPORT FUNCTION
# ============================================================================

function Export-QuotaDataToCsv {
    param(
        [PSCustomObject[]]$QuotaData,
        [string]$OutputPath
    )
    
    if ($null -eq $QuotaData -or $QuotaData.Count -eq 0) {
        Write-LogWarning "No quota data to export to CSV"
        return $null
    }
    
    $csvFileName = "$OutputPath\quota_audit_$reportDateTime.csv"
    
    $QuotaData |
        Sort-Object -Property Subscription, Region, ResourceType |
        Select-Object -Property Subscription, SubscriptionId, Region, ResourceType, ResourceLocalizedName, CurrentCount, Limit, RemainingCapacity, PercentageUsed, Status, CollectionTime |
        Export-Csv -Path $csvFileName -NoTypeInformation -Encoding UTF8 -Force
    
    Write-LogInfo "CSV report generated: $csvFileName"
    return $csvFileName
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    try {
        Write-Banner
        
        Write-LogInfo "Starting Azure Quota Audit"
        Write-LogInfo "Configuration: OutputPath=$OutputPath, HighThreshold=$HighThreshold%, CriticalThreshold=$CriticalThreshold%"
        
        # Authenticate to Azure using managed identity
        Connect-AzureWithManagedIdentity
        
        # Collect quota data
        Write-LogInfo "Collecting quota usage data..."
        $quotaData = Get-QuotaUsageData -SubscriptionNames $SubscriptionNames -HighThreshold $HighThreshold -CriticalThreshold $CriticalThreshold
        
        if ($null -eq $quotaData) {
            Write-LogWarning "No quota data collected"
            return
        }
        
        Write-LogInfo "Successfully collected quota data for $($quotaData.Count) resources"
        
        # Generate reports based on output format
        $generatedFiles = @()
        
        if ($OutputFormat -in @('HTML', 'Both')) {
            Write-LogInfo "Generating HTML reports..."
            
            # Report with used resources
            $usedFile = New-HTMLReport -QuotaData $quotaData -OutputPath $OutputPath -Title "Active Resources"
            if ($usedFile) { $generatedFiles += $usedFile }
            
            # Report with all resources
            $allFile = New-HTMLReport -QuotaData $quotaData -OutputPath $OutputPath -Title "All Resources" -IncludeAllResources
            if ($allFile) { $generatedFiles += $allFile }
        }
        
        if ($OutputFormat -in @('CSV', 'Both')) {
            Write-LogInfo "Exporting to CSV..."
            $csvFile = Export-QuotaDataToCsv -QuotaData $quotaData -OutputPath $OutputPath
            if ($csvFile) { $generatedFiles += $csvFile }
        }
        
        # Summary statistics
        Write-LogInfo "Audit Summary:"
        Write-Host "  Total Resources: $($quotaData.Count)" -ForegroundColor Cyan
        Write-Host "  Critical Status: $(($quotaData | Where-Object {$_.Status -eq 'Critical'}).Count)" -ForegroundColor Red
        Write-Host "  High Status: $(($quotaData | Where-Object {$_.Status -eq 'High'}).Count)" -ForegroundColor Yellow
        Write-Host "  Normal Status: $(($quotaData | Where-Object {$_.Status -eq 'Normal'}).Count)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Generated Files:" -ForegroundColor Green
        foreach ($file in $generatedFiles) {
            Write-Host "  → $file" -ForegroundColor Cyan
        }
        
        Write-LogInfo "Audit completed successfully"
    }
    catch {
        Write-LogError "Script execution failed: $_"
        exit 1
    }
}

# Execute main function
Main
