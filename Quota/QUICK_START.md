# Azure Quota Audit - Quick Start Guide

## 5-Minute Setup

### Step 1: Install Required Modules (if running locally)
```powershell
Install-Module -Name Az.Accounts -Force -AllowClobber
Install-Module -Name Az.Compute -Force -AllowClobber
```

### Step 2: Authenticate (if running locally)
```powershell
# Azure CLI authentication (recommended)
az login

# OR use PowerShell
Connect-AzAccount
```

### Step 3: Run the Script

**Option A: Default (Audit all accessible subscriptions)**
```powershell
cd c:\.git\AzureScripts\Quota
.\audit_sku_quota_usage_refactored.ps1
```

**Option B: Specific subscriptions only**
```powershell
.\audit_sku_quota_usage_refactored.ps1 -SubscriptionNames 'MyProdSub', 'MyTestSub'
```

**Option C: Custom output location and thresholds**
```powershell
.\audit_sku_quota_usage_refactored.ps1 -OutputPath 'C:\reports' -HighThreshold 75 -CriticalThreshold 85
```

### Step 4: View Reports
Reports are automatically generated in your output path (default: `c:\temp`):
1. `quota_audit_active_resources_*.html` - Active resources only
2. `quota_audit_all_resources_*.html` - All resources (if `-IncludeUnused` used)
3. `quota_audit_*.csv` - Data in CSV format

Simply double-click any HTML file to open in your browser!

---

## Common Scenarios

### Audit Specific Subscription
```powershell
.\audit_sku_quota_usage_refactored.ps1 -SubscriptionNames 'Production'
```

### Use Default Azure Context
The script automatically uses your current Azure authentication. No environment parameters needed:
```powershell
# Authenticate once, then run multiple audits
az login
.\audit_sku_quota_usage_refactored.ps1
```

### Generate Only CSV (for analysis/automation)
```powershell
.\audit_sku_quota_usage_refactored.ps1 -OutputFormat CSV
```

### Lower Sensitivity (more tolerant thresholds)
```powershell
.\audit_sku_quota_usage_refactored.ps1 -HighThreshold 85 -CriticalThreshold 95
```

### Save Reports to Network Share
```powershell
.\audit_sku_quota_usage_refactored.ps1 -OutputPath '\\server\share\quota-reports'
```

### Include Unused Resources in Reports
```powershell
.\audit_sku_quota_usage_refactored.ps1 -IncludeUnused
```

---

## Understanding the Output

### HTML Report
- **Red boxes** = Quota at 90%+ - Urgent action needed
- **Orange boxes** = Quota at 80%+ - Monitor closely
- **Blue boxes** = Quota at 0-80% - Healthy
- **Gray boxes** = 0% usage - Not currently in use

### CSV File
Use for:
- Importing into Excel
- Automation and alerting
- Tracking over time
- Integration with other tools

### Console Output Shows
- ✅ Successful connections
- 📊 Resource count summary
- 🔴 Critical resource count
- 🟠 High resource count
- 🔵 Normal resource count
- 📁 Generated file locations

---

## Troubleshooting

**Error: "No subscriptions found"**
```powershell
# Check your subscriptions
Get-AzSubscription

# Authenticate using Azure CLI
az login
```

**Error: "AccessDenied" or "Not authenticated"**
- Ensure you've authenticated: `az login` or `Connect-AzAccount`
- Ensure your account has Reader role on subscriptions
- Try authenticating again with: `az login --allow-no-subscriptions` or `Connect-AzAccount -Force`

**No reports generated?**
- Verify output path exists: `Test-Path c:\temp`
- Create path if needed: `New-Item -Path c:\temp -ItemType Directory -Force`
- Check if you have permission to write to the directory

---

## Automation: Run Daily

### Option 1: Azure Automation Runbook (Recommended)
Uses managed identity - no credentials needed:

1. Create new PowerShell runbook in Azure Automation
2. Copy the script content
3. Create a schedule (e.g., Daily at 2 AM)
4. Ensure the automation account has Reader role on target subscriptions
5. Run the script as-is - it will use the managed identity automatically

```powershell
# In Azure Automation - runs with managed identity
.\audit_sku_quota_usage_refactored.ps1 -OutputPath 'C:\scheduled-reports'
```

### Option 2: Windows Task Scheduler (Local/VM)
```powershell
# Create task that runs at 2 AM daily
# Requires local Azure CLI authentication: az login
$trigger = New-ScheduledTaskTrigger -Daily -At 2AM
$action = New-ScheduledTaskAction -Program 'powershell.exe' -Arguments @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-Command', "cd 'c:\.git\AzureScripts\Quota'; .\audit_sku_quota_usage_refactored.ps1 -OutputPath 'C:\scheduled-reports'"
)
Register-ScheduledTask -TaskName 'AzureQuotaAudit' -Action $action -Trigger $trigger
```

### Option 3: Azure Functions (Serverless)
Uses managed identity as function app identity:
```powershell
# Deploy as Azure Function with timer trigger
# Script runs with function's managed identity
```

---

## Next Steps

1. **Review the first report** to understand your current quota usage
2. **Identify resources at critical levels** (red status)
3. **Plan quota increases** for growing resources
4. **Schedule regular audits** (daily or weekly)
5. **Set up alerting** when quotas exceed thresholds

---

## Support Resources

- Microsoft Docs: https://docs.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits
- Request Quota Increase: Azure Portal → Subscriptions → Usage + quotas
- Azure Advisor: Get recommendations in Azure Portal

---

**Questions?** Check `REFACTORING_GUIDE.md` for detailed documentation.
