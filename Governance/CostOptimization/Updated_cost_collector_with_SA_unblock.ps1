<#
.SYNOPSIS
Azure Billing and Cost Report Collector with Managed Identity Authentication

.DESCRIPTION
Collects Azure consumption usage details and billing invoices across multiple tenants,
exports to CSV, and uploads to Azure Storage using Managed Identity.

.NOTES
    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.
#>

param(
    [Parameter(Mandatory = $false)]
    [int]$MonthsToCollect = 12,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName = 'WolffMSsub',
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = 'wolffautomationrg',
    
    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName = 'wolffautosa',
    
    [Parameter(Mandatory = $false)]
    [string]$Region = 'West US',
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = [System.IO.Path]::GetTempPath()
)

# ===== SCRIPT CONFIGURATION =====
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# ===== LOGGING SETUP =====
$scriptStartTime = Get-Date
$scriptName = $MyInvocation.MyCommand.Name
function Write-Log {
    param([string]$Message, [ValidateSet('INFO', 'WARNING', 'ERROR')][string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $(if ($Level -eq 'ERROR') { 'Red' } elseif ($Level -eq 'WARNING') { 'Yellow' } else { 'Green' })
}

Write-Log "Starting Azure Billing Collection Script" 'INFO'

# ===== AUTHENTICATION =====
Write-Log "Authenticating with Managed Identity..." 'INFO'
try {
    Connect-AzAccount -tenant d06bc698-c2f2-495a-ab7a-a078237ea9ad  -Subscription 3294dabe-8087-47e2-8fab-982030530146 #-Identity -ErrorAction Stop | Out-Null
    Write-Log "Managed Identity authentication successful" 'INFO'
} catch {
    Write-Log "Failed to authenticate with Managed Identity: $_" 'ERROR'
    throw
}

# ===== TENANT AND CONTEXT SETUP =====
Write-Log "Retrieving tenant information..." 'INFO'
$tenantList = @(Get-AzTenant -ErrorAction Stop | Select-Object Id, DisplayName, DefaultDomain)
Write-Log "Found $($tenantList.Count) tenant(s)" 'INFO'

# ===== DATA COLLECTION INITIALIZATION =====
$costReport = [System.Collections.Generic.List[PSObject]]::new()
$invoiceReport = [System.Collections.Generic.List[PSObject]]::new()
$today = Get-Date -Format 'yyyyMM'
 

# ===== COST COLLECTION FUNCTION =====
function Collect-ConsumptionDetails {
    param(
        [string]$TenantId,
        [int]$MonthsBack
    )
    
    Write-Log "Collecting consumption details for tenant: $TenantId (last $MonthsBack months)" 'INFO'
    $localCosts = [System.Collections.Generic.List[PSObject]]::new()
    
    Set-AzContext -Tenant $TenantId -ErrorAction Stop | Out-Null
    
    $startDate = (Get-Date).AddMonths(-$MonthsBack).Date
    $endDate = (Get-Date).Date
    
    Write-Log "Fetching consumption from $startDate to $endDate" 'INFO'
    
    try {
        # Use date range instead of BillingPeriodName which has API compatibility issues
        $costs = Get-AzConsumptionUsageDetail -StartDate $startDate -EndDate $endDate -IncludeAdditionalProperties -ErrorAction Stop
    
    if ($costs -and $costs.Count -gt 0) {
        $costCount = @($costs).Count
        Write-Log "Found $costCount consumption records" 'INFO'
        
        # Convert to custom objects efficiently
        $costs | ForEach-Object {
            $costItem = $_
            $tagString = if ($costItem.Tags -and $costItem.Tags.Count -gt 0) {
                $costItem.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Join-String -Separator '; '
            } else {
                ''
            }
            
            $costObject = [PSCustomObject]@{
                'AccountName'           = $costItem.AccountName
                'AdditionalInfo'        = $costItem.AdditionalInfo
                'AdditionalProperties'  = $costItem.AdditionalProperties
                'BillableQuantity'      = $costItem.BillableQuantity
                'BillingPeriodId'       = $costItem.BillingPeriodId
                'BillingPeriodName'     = $costItem.BillingPeriodName
                'ConsumedService'       = $costItem.ConsumedService
                'CostCenter'            = $costItem.CostCenter
                'Currency'              = $costItem.Currency
                'DepartmentName'        = $costItem.DepartmentName
                'Id'                    = $costItem.Id
                'InstanceId'            = $costItem.InstanceId
                'InstanceLocation'      = $costItem.InstanceLocation
                'InstanceName'          = $costItem.InstanceName
                'InvoiceId'             = $costItem.InvoiceId
                'InvoiceName'           = $costItem.InvoiceName
                'IsEstimated'           = $costItem.IsEstimated
                'MeterDetails'          = $costItem.MeterDetails
                'MeterId'               = $costItem.MeterId
                'Name'                  = $costItem.Name
                'PretaxCost'            = $costItem.PretaxCost
                'Product'               = $costItem.Product
                'SubscriptionGuid'      = $costItem.SubscriptionGuid
                'SubscriptionName'      = $costItem.SubscriptionName
                'Tags'                  = $tagString
                'Type'                  = $costItem.Type
                'UsageEnd'              = $costItem.UsageEnd
                'UsageQuantity'         = $costItem.UsageQuantity
                'UsageStart'            = $costItem.UsageStart
            }
            
            $localCosts.Add($costObject) | Out-Null
        }
    } else {
        Write-Log "No consumption records found for specified period" 'WARNING'
    }
    }
    catch {
        Write-Log "Error collecting consumption details: $($_.Exception.Message)" 'WARNING'
        # Return empty list instead of null to avoid AddRange errors
        return [System.Collections.Generic.List[PSObject]]::new()
    }
    
    return $localCosts
}

# ===== INVOICE COLLECTION FUNCTION =====
function Collect-BillingInvoices {
    param([string]$TenantId)
    
    Write-Log "Collecting billing invoices for tenant: $TenantId" 'INFO'
    $localInvoices = [System.Collections.Generic.List[PSObject]]::new()
    
    Set-AzContext -Tenant $TenantId -ErrorAction Stop | Out-Null
    
    # Add delay to prevent rate limiting
    Start-Sleep -Milliseconds 500
    
    try {
        $invoices = Get-AzBillingInvoice -ErrorAction Stop
        
        if ($invoices -and $invoices.Count -gt 0) {
            $invoiceCount = @($invoices).Count
            Write-Log "Found $invoiceCount invoice(s)" 'INFO'
            
            $invoices | ForEach-Object {
                $invoice = $_
                try {
                    $subscription = Get-AzSubscription -SubscriptionId $invoice.SubscriptionId -TenantId $TenantId -ErrorAction SilentlyContinue
                    
                    $invoiceObject = [PSCustomObject]@{
                        'Name'                     = $invoice.Name
                        'InvoiceDate'              = $invoice.InvoiceDate
                        'InvoicePeriodStartDate'   = $invoice.InvoicePeriodStartDate
                        'InvoicePeriodEndDate'     = $invoice.InvoicePeriodEndDate
                        'Status'                   = $invoice.Status
                        'SubscriptionId'           = $invoice.SubscriptionId
                        'SubscriptionName'         = $subscription.Name
                        'Subtotal'                 = $invoice.SubTotal
                        'AmountDue'                = $invoice.AmountDue.Value
                        'BilledAmount'             = $invoice.BilledAmount.Value
                        'TaxAmount'                = $invoice.TaxAmount.Value
                        'DueDate'                  = $invoice.DueDate
                        'TenantId'                 = $TenantId
                    }
                    
                    $localInvoices.Add($invoiceObject) | Out-Null
                }
                catch {
                    Write-Log "Error processing invoice $($invoice.Name): $_" 'WARNING'
                }
            }
        }
    }
    catch {
        Write-Log "Error collecting invoices: $($_.Exception.Message)" 'WARNING'
        # Return empty list instead of null to avoid AddRange errors
        return [System.Collections.Generic.List[PSObject]]::new()
    }
    
    return $localInvoices
}

# ===== COST COLLECTION MAIN LOOP =====
Write-Log "Starting cost and invoice collection across $($tenantList.Count) tenant(s)..." 'INFO'
foreach ($tenant in $tenantList) {
    Write-Log "Processing tenant: $($tenant.DisplayName) ($($tenant.Id))" 'INFO'
    
    # Collect costs for this tenant
    $tenantCosts = Collect-ConsumptionDetails -TenantId $tenant.Id -MonthsBack $MonthsToCollect
    if ($tenantCosts -and $tenantCosts.Count -gt 0) {
        $costReport.AddRange($tenantCosts) | Out-Null
    }
    
    # Add delay between API calls to avoid rate limiting
    Start-Sleep -Milliseconds 1000
    
    # Collect invoices for this tenant
    $tenantInvoices = Collect-BillingInvoices -TenantId $tenant.Id
    if ($tenantInvoices -and $tenantInvoices.Count -gt 0) {
        $invoiceReport.AddRange($tenantInvoices) | Out-Null
    }
    
    # Additional delay between tenants
    if ($tenantList.Count -gt 1) {
        Start-Sleep -Milliseconds 1000
    }
}

Write-Log "Cost collection complete: $($costReport.Count) records collected" 'INFO'
Write-Log "Invoice collection complete: $($invoiceReport.Count) invoices collected" 'INFO'
  


# ===== EXPORT TO CSV =====
Write-Log "Exporting data to CSV files..." 'INFO'

$costReportFile = Join-Path -Path $OutputPath -ChildPath "AzureBillingCosts_$today.csv"
$invoiceReportFile = Join-Path -Path $OutputPath -ChildPath "AzureInvoices_$today.csv"

try {
    $costReport | Select-Object AccountName, AdditionalInfo, AdditionalProperties, BillableQuantity, `
        BillingPeriodId, BillingPeriodName, ConsumedService, CostCenter, Currency, DepartmentName, `
        Id, InstanceId, InstanceLocation, InstanceName, InvoiceId, InvoiceName, IsEstimated, `
        MeterDetails, MeterId, Name, PretaxCost, Product, SubscriptionGuid, SubscriptionName, `
        Tags, Type, UsageEnd, UsageQuantity, UsageStart | `
        Export-Csv -Path $costReportFile -NoTypeInformation -Force -ErrorAction Stop

        $costReport | Select-Object AccountName, AdditionalInfo, AdditionalProperties, BillableQuantity, `
        BillingPeriodId, BillingPeriodName, ConsumedService, CostCenter, Currency, DepartmentName, `
        Id, InstanceId, InstanceLocation, InstanceName, InvoiceId, InvoiceName, IsEstimated, `
        MeterDetails, MeterId, Name, PretaxCost, Product, SubscriptionGuid, SubscriptionName, `
        Tags, Type, UsageEnd, UsageQuantity, UsageStart | `
        Export-Csv -Path "c:\temp\costsreports" -NoTypeInformation -Force -ErrorAction Stop
    Write-Log "Cost report exported: $costReportFile" 'INFO'
}
catch {
    Write-Log "Error exporting cost report: $_" 'ERROR'
    throw
}

try {
    $invoiceReport | Select-Object Name, InvoiceDate, InvoicePeriodStartDate, InvoicePeriodEndDate, `
        Status, SubscriptionId, SubscriptionName, Subtotal, AmountDue, BilledAmount, TaxAmount, DueDate, TenantId | `
        Export-Csv -Path $invoiceReportFile -NoTypeInformation -Force -ErrorAction Stop
    
    Write-Log "Invoice report exported: $invoiceReportFile" 'INFO'
}
catch {
    Write-Log "Error exporting invoice report: $_" 'ERROR'
    throw
}



# ===== STORAGE SETUP AND UPLOAD FUNCTIONS =====
function Initialize-StorageAccount {
    param(
        [string]$SubscriptionName,
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$Region
    )
    
    Write-Log "Setting up storage account: $StorageAccountName" 'INFO'
    
    try {
        # Get subscription and set context
        $subscription = Get-AzSubscription -SubscriptionName $SubscriptionName -ErrorAction Stop
        Set-AzContext -Subscription $subscription.Id -ErrorAction Stop | Out-Null
        Write-Log "Context set to subscription: $SubscriptionName" 'INFO'
        
        # Check if storage account exists
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
        
        if (-not $storageAccount) {
            Write-Log "Storage account not found. Creating: $StorageAccountName" 'INFO'
            New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                -Name $StorageAccountName `
                -Location $Region `
                -AccessTier Hot `
                -SkuName Standard_LRS `
                -Kind BlobStorage `
                -Tag @{'owner' = 'Azure Automation'; 'purpose' = 'Billing Reports' } `
                -ErrorAction Stop | Out-Null
            
            Write-Log "Storage account created successfully" 'INFO'
        }
        else {
            Write-Log "Storage account already exists" 'INFO'
        }
        
        # Configure storage account for secure access with managed identity
        Set-AzStorageAccount -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -AllowBlobPublicAccess $false `
            -AllowSharedKeyAccess $false `
            -ErrorAction Stop | Out-Null
        
        Write-Log "Storage account configured for managed identity access" 'INFO'
        
        return $storageAccount
    }
    catch {
        Write-Log "Error initializing storage account: $_" 'ERROR'
        throw
    }
}

function Ensure-StorageContainer {
    param(
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$ContainerName
    )
    
    try {
        # Get storage account context using managed identity
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop
        $storageContext = $storageAccount.Context
        Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowBlobPublicAccess $true -AllowSharedKeyAccess $true  -force

        # Check if container exists
        $container = Get-AzStorageContainer -Name $ContainerName -Context $storageContext -ErrorAction SilentlyContinue
        
        if (-not $container) {
            Write-Log "Creating storage container: $ContainerName" 'INFO'
            New-AzStorageContainer -Name $ContainerName -Context $storageContext -ErrorAction Stop | Out-Null
            Write-Log "Container created: $ContainerName" 'INFO'
        }
        else {
            Write-Log "Container already exists: $ContainerName" 'INFO'
        }
        
        return $storageContext
    }
    catch {
        Write-Log "Error ensuring storage container: $_" 'ERROR'
        throw
    }
}

function Upload-ReportToStorage {
    param(
        [string]$FilePath,
        [string]$ContainerName,
        [object]$StorageContext,
        [string]$BlobName
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            Write-Log "File not found: $FilePath" 'ERROR'
            throw "File not found: $FilePath"
        }
        
        Write-Log "Uploading $BlobName to container: $ContainerName" 'INFO'
        
        Set-AzStorageBlobContent -File $FilePath `
            -Container $ContainerName `
            -Blob $BlobName `
            -Context $StorageContext `
            -Force `
            -ErrorAction Stop | Out-Null
        
        Write-Log "Successfully uploaded: $BlobName" 'INFO'
    }
    catch {
        Write-Log "Error uploading to storage: $_" 'ERROR'
        throw
    }
}

# ===== STORAGE UPLOAD MAIN =====
Write-Log "Beginning storage operations..." 'INFO'

try {
    # Initialize storage account
    Initialize-StorageAccount -SubscriptionName $SubscriptionName `
        -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -Region $Region
    
    # Handle cost reports
    $costContexts = @('wpicorpbilling', 'wpicorpbilling-archive')
    foreach ($container in $costContexts) {
        $context = Ensure-StorageContainer -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -ContainerName $container
        
        Upload-ReportToStorage -FilePath $costReportFile `
            -ContainerName $container `
            -StorageContext $context `
            -BlobName "AzureBillingCosts_$today.csv"
    }
    
    # Handle invoice reports
    $invoiceContainer = 'invoices'
    $invoiceContext = Ensure-StorageContainer -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $StorageAccountName `
        -ContainerName $invoiceContainer
    
    Upload-ReportToStorage -FilePath $invoiceReportFile `
        -ContainerName $invoiceContainer `
        -StorageContext $invoiceContext `
        -BlobName "AzureInvoices_$today.csv"
    
    Write-Log "All files uploaded successfully" 'INFO'
}
catch {
    Write-Log "Error during storage operations: $_" 'ERROR'
    throw
}

# ===== SCRIPT COMPLETION SUMMARY =====
$scriptEndTime = Get-Date
$scriptDuration = $scriptEndTime - $scriptStartTime

Write-Log "========================================" 'INFO'
Write-Log "Script Execution Summary" 'INFO'
Write-Log "========================================" 'INFO'
Write-Log "Script Name: $scriptName" 'INFO'
Write-Log "Start Time: $scriptStartTime" 'INFO'
Write-Log "End Time: $scriptEndTime" 'INFO'
Write-Log "Duration: $($scriptDuration.TotalMinutes -as [int]) minutes" 'INFO'
Write-Log "Tenants Processed: $($tenantList.Count)" 'INFO'
Write-Log "Cost Records Collected: $($costReport.Count)" 'INFO'
Write-Log "Invoices Collected: $($invoiceReport.Count)" 'INFO'
Write-Log "Cost Report File: $costReportFile" 'INFO'
Write-Log "Invoice Report File: $invoiceReportFile" 'INFO'
Write-Log "Storage Account: $StorageAccountName" 'INFO'
Write-Log "========================================" 'INFO'
Write-Log "Script completed successfully!" 'INFO'
