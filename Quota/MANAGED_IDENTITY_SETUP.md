# Managed Identity Setup Guide

This guide explains how to set up and run the Azure Quota Audit script with managed identity in various Azure environments.

## Overview

The refactored script uses **managed identity** for authentication, eliminating the need to hardcode credentials or manage connection parameters. This is the recommended approach for:

- ✅ Azure Automation Runbooks
- ✅ Azure Functions
- ✅ Azure Container Instances
- ✅ Azure Virtual Machines with managed identity
- ✅ Any Azure service with system-assigned or user-assigned identity

## Local Development (Without Managed Identity)

### Option 1: Azure CLI (Recommended)
```powershell
# Authenticate once using Azure CLI (works across all CLIs)
az login

# Run the script - it will use Azure CLI context
.\audit_sku_quota_usage_refactored.ps1
```

### Option 2: PowerShell Connect-AzAccount
```powershell
# Authenticate
Connect-AzAccount

# Run the script
.\audit_sku_quota_usage_refactored.ps1
```

### Option 3: Connect with Specific Subscription
```powershell
# Specify subscription
Connect-AzAccount -Subscription 'subscription-name-or-id'

# Run the script
.\audit_sku_quota_usage_refactored.ps1
```

For multi-subscription audits:
```powershell
# Connect once, specify subscriptions in script
.\audit_sku_quota_usage_refactored.ps1 -SubscriptionNames 'Sub1', 'Sub2', 'Sub3'
```

---

## Azure Automation Runbook Setup

### Step 1: Create Automation Account
```powershell
# Create automation account if not exists
$resourceGroupName = 'my-resource-group'
$automationAccountName = 'my-automation-account'

New-AzAutomationAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $automationAccountName `
    -Location 'East US'
```

### Step 2: Enable System Assigned Identity
```powershell
$automationAccount = Get-AzAutomationAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $automationAccountName

# System assigned identity is created by default, verify it
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName `
    -Name $automationAccountName -ErrorAction SilentlyContinue

if ($null -eq $identity) {
    Write-Host "System-assigned identity is enabled"
}
```

### Step 3: Grant Reader Role to Managed Identity
```powershell
# Get the service principal of the automation account
$sp = Get-AzADServicePrincipal -DisplayName $automationAccountName

# Assign Reader role to all subscriptions
$subscriptions = Get-AzSubscription

foreach ($subscription in $subscriptions) {
    New-AzRoleAssignment `
        -ObjectId $sp.Id `
        -RoleDefinitionName 'Reader' `
        -Scope "/subscriptions/$($subscription.Id)" `
        -ErrorAction SilentlyContinue
}

Write-Host "Assigned Reader role to automation account across subscriptions"
```

### Step 4: Create PowerShell Runbook
```powershell
# In Azure Portal:
# 1. Go to Automation Account
# 2. Click "Runbooks" → "Create a runbook"
# 3. Name: "Audit-AzureQuotas"
# 4. Type: "PowerShell"
# 5. Runtime version: "7.2" (or latest)
# 6. Click "Create"

# In the editor, paste the entire script content from:
# audit_sku_quota_usage_refactored.ps1
```

### Step 5: Create Schedule (Optional)
```powershell
# Create a daily schedule
$resourceGroupName = 'my-resource-group'
$automationAccountName = 'my-automation-account'
$runbookName = 'Audit-AzureQuotas'

# Schedule to run daily at 2 AM
$schedule = New-AzAutomationSchedule `
    -ResourceGroupName $resourceGroupName `
    -AutomationAccountName $automationAccountName `
    -Name 'Daily-Quota-Audit' `
    -StartTime (Get-Date).AddDays(1).Date.AddHours(2) `
    -Interval 1 `
    -Frequency Day

# Link schedule to runbook
Register-AzAutomationScheduledRunbook `
    -ResourceGroupName $resourceGroupName `
    -AutomationAccountName $automationAccountName `
    -RunbookName $runbookName `
    -ScheduleName 'Daily-Quota-Audit'
```

### Step 6: Run from Azure Portal
1. Go to Automation Account → Runbooks
2. Select "Audit-AzureQuotas"
3. Click "Start"
4. Optionally enter parameters:
   - OutputPath: `C:\temp` (or Storage Account path)
   - SubscriptionNames: `Sub1,Sub2` (comma-separated)
   - HighThreshold: `80`
   - CriticalThreshold: `90`

### Step 7: Store Reports in Storage Account
```powershell
# Create storage account if not exists
$storageAccountName = 'quotareportsstorage'
$resourceGroupName = 'my-resource-group'
$location = 'East US'

$storageAccount = New-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -SkuName 'Standard_LRS' `
    -Location $location

# Create container for reports
$ctx = $storageAccount.Context
New-AzStorageContainer -Name 'quota-reports' -Context $ctx

# Get storage account key
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value

# Store for later use
Write-Host "Storage Account: $storageAccountName"
Write-Host "Key: $storageKey"
```

### Step 8: Update Runbook to Upload Reports
```powershell
# In the runbook, after the script completes, add:

$storageAccountName = 'your-storage-account-name'
$storageAccountKey = 'your-storage-account-key'
$containerName = 'quota-reports'

# Get storage context
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

# Upload HTML reports
Get-ChildItem 'c:\temp\quota_audit_*.html' | ForEach-Object {
    Set-AzStorageBlobContent `
        -File $_.FullName `
        -Container $containerName `
        -Blob $_.Name `
        -Context $storageContext `
        -Force
}

Write-Output "Reports uploaded successfully"
```

---

## Azure Functions Setup

### Step 1: Create Function App
```powershell
$functionAppName = 'quota-audit-function'
$resourceGroupName = 'my-resource-group'
$storageAccountName = 'functionstorage'
$location = 'East US'

# Create storage account for function
$storageAccount = New-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -SkuName 'Standard_LRS' `
    -Location $location

# Create function app
New-AzFunctionApp `
    -ResourceGroupName $resourceGroupName `
    -Name $functionAppName `
    -StorageAccount $storageAccountName `
    -Runtime PowerShell `
    -RuntimeVersion 7.4 `
    -FunctionsVersion 4 `
    -IdentityType SystemAssigned
```

### Step 2: Assign Reader Role
```powershell
$functionApp = Get-AzFunctionApp `
    -ResourceGroupName $resourceGroupName `
    -Name $functionAppName

# Get the service principal ID
$principalId = $functionApp.Identity.PrincipalId

# Assign Reader role
New-AzRoleAssignment `
    -ObjectId $principalId `
    -RoleDefinitionName 'Reader' `
    -Scope '/subscriptions/your-subscription-id'
```

### Step 3: Create Timer Trigger Function
```powershell
# Deploy function with timer trigger
func new -n QuotaAudit -t timerTrigger

# In run.ps1, add the audit script logic
```

---

## Troubleshooting Managed Identity

### Check if Managed Identity is Working
```powershell
# In Azure Automation runbook:
try {
    # Attempt to use managed identity
    $vm = Connect-AzAccount -Identity
    Write-Output "✓ Managed identity authentication successful"
    Write-Output "Account: $(Get-AzContext | Select-Object Account)"
} catch {
    Write-Error "✗ Managed identity failed: $_"
    Write-Output "Fallback: Using default Azure context"
    $context = Get-AzContext
    if ($null -eq $context) {
        Write-Error "Not authenticated"
    }
}
```

### Grant Permissions Script
```powershell
function Grant-QuotaAuditPermissions {
    param(
        [string]$AutomationAccountName,
        [string]$ResourceGroupName
    )
    
    try {
        # Get service principal
        $sp = Get-AzADServicePrincipal -DisplayName $AutomationAccountName
        
        if ($null -eq $sp) {
            Write-Error "Service principal not found"
            return
        }
        
        # Get all subscriptions
        $subscriptions = Get-AzSubscription
        
        # Assign Reader role
        foreach ($sub in $subscriptions) {
            Write-Host "Granting Reader role on subscription: $($sub.Name)"
            
            New-AzRoleAssignment `
                -ObjectId $sp.Id `
                -RoleDefinitionName 'Reader' `
                -Scope "/subscriptions/$($sub.Id)" `
                -ErrorAction SilentlyContinue
        }
        
        Write-Host "✓ Permissions granted successfully"
    }
    catch {
        Write-Error "Failed to grant permissions: $_"
    }
}

# Usage
Grant-QuotaAuditPermissions -AutomationAccountName 'my-automation-account' -ResourceGroupName 'my-rg'
```

---

## Security Best Practices

1. **Use System-Assigned Identity**: Simpler and recommended for single-resource scenarios
2. **Use User-Assigned Identity**: Better for multi-resource or multi-subscription scenarios
3. **Principle of Least Privilege**: Use 'Reader' role, not 'Contributor'
4. **Store Reports Securely**: Use Storage Account with access restrictions
5. **Enable Audit Logging**: Track runbook executions
6. **Rotate Keys**: If using storage account keys, rotate regularly
7. **Network Security**: Use VNet integration for function apps if needed

---

## Cost Optimization

- **Azure Automation**: ~$0.50/month for up to 500 job minutes
- **Azure Functions**: Free tier covers 1M requests and 400k GB-seconds
- **Storage Account**: Pay-as-you-go for report storage

---

## Monitoring & Alerts

### Monitor Runbook Execution
```powershell
# Check last execution
Get-AzAutomationJob `
    -ResourceGroupName 'my-rg' `
    -AutomationAccountName 'my-automation' `
    -RunbookName 'Audit-AzureQuotas' `
    -Latest | Format-List
```

### Set Up Alerts
```powershell
# Create alert for failed runbook execution
$resourceGroupName = 'my-resource-group'
$automationAccountName = 'my-automation-account'

# Get automation account resource ID
$resource = Get-AzResource `
    -ResourceGroupName $resourceGroupName `
    -ResourceName $automationAccountName `
    -ResourceType 'Microsoft.Automation/automationAccounts'

# Create metric alert (customize as needed)
# Can be done via Azure Portal or PowerShell
```

---

## References

- [Azure Managed Identities](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Azure Automation Managed Identity](https://learn.microsoft.com/en-us/azure/automation/enable-managed-identity-for-automation)
- [Azure Functions Identity](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell)
- [Azure RBAC Built-in Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
