# Azure Quota Usage Audit Script - Refactored Version

## Overview
This refactored script audits Azure subscription quotas and usage across all regions, generating professional HTML and CSV reports with color-coded usage indicators. The script uses managed identity for secure Azure authentication without hardcoded credentials.

## Key Improvements

### 1. **Code Quality & Maintainability**
- ✅ Proper function-based architecture with single responsibility principle
- ✅ Comprehensive comment documentation and help text
- ✅ Fixed variable naming issues (removed typos like `$subb` → `$sub`)
- ✅ Standardized code formatting and removed excessive whitespace
- ✅ Use of proper error handling with try-catch blocks

### 2. **Parameters & Flexibility**
- ✅ Configurable parameters instead of hardcoded values:
  - `SubscriptionNames`: Audit specific subscriptions
  - `OutputPath`: Customize report location
  - `OutputFormat`: Choose HTML, CSV, or Both
  - `HighThreshold` & `CriticalThreshold`: Customize alert thresholds
  - `IncludeUnused`: Toggle unused resources in reports
- ✅ Managed identity authentication - no credentials stored in code
- ✅ Automatic Azure CLI authentication detection

### 3. **Enhanced HTML Reports**
- ✅ Professional, modern design with responsive layout
- ✅ Summary statistics dashboard with visual indicators
- ✅ Color-coded status badges (Critical, High, Normal, Unused)
- ✅ Progress bars showing percentage usage visually
- ✅ Legend explaining status thresholds
- ✅ Detailed table with sortable columns
- ✅ Clean typography using Segoe UI
- ✅ Print-friendly formatting

### 4. **Data Collection Improvements**
- ✅ Removed undefined variables (`$Corecountrequests`, `$percentagelimit`)
- ✅ Proper error handling for region queries
- ✅ Status classification (Critical/High/Normal/Unused)
- ✅ Remaining capacity calculation
- ✅ Collection timestamp for auditing
- ✅ Unique resource identification per subscription/region

### 5. **Logging & Visibility**
- ✅ Structured logging functions (Write-LogInfo, Write-LogError, Write-LogWarning)
- ✅ Progress indicators for long-running operations
- ✅ Console summary with color-coded output
- ✅ Detailed file generation feedback

### 6. **Output Files**
- ✅ Timestamped file names for audit trail
- ✅ HTML reports for active resources AND all resources (separate files)
- ✅ CSV export for data analysis and archiving
- ✅ UTF-8 encoding for international character support

## Usage Examples

### Basic Usage (Default Settings)
```powershell
.\audit_sku_quota_usage_refactored.ps1
```

### Audit Specific Subscriptions
```powershell
.\audit_sku_quota_usage_refactored.ps1 -SubscriptionNames 'ProdSubscription', 'TestSubscription' -OutputPath 'C:\Reports'
```

### Custom Thresholds
```powershell
.\audit_sku_quota_usage_refactored.ps1 -HighThreshold 75 -CriticalThreshold 90 -OutputFormat HTML
```

### Include Unused Resources
```powershell
.\audit_sku_quota_usage_refactored.ps1 -IncludeUnused -OutputFormat CSV
```

## Output Files

### HTML Reports
- **quota_audit_active_resources_YYYY-MM-DD_HHMMSS.html**: Shows only resources with current usage > 0
- **quota_audit_all_resources_YYYY-MM-DD_HHMMSS.html**: Shows all resources including unused (if `-IncludeUnused` is used)

### CSV Export
- **quota_audit_YYYY-MM-DD_HHMMSS.csv**: Machine-readable format for further analysis

## HTML Report Features

### Summary Dashboard
Shows at a glance:
- Total resources analyzed
- Critical status count (≥90% by default)
- High status count (≥80% by default)
- Normal status resources
- Unused resources (0% usage)

### Detailed Table
Displays:
- Subscription name and ID
- Region/Location
- Resource type with localized name
- Current usage count
- Quota limit
- Remaining capacity
- Usage percentage with visual bar
- Status badge with color coding

### Color Scheme
- 🔴 **Red** (#EA1E63): Critical - Immediate attention needed (≥90%)
- 🟠 **Orange** (#F1576C): High - Monitor closely (≥80%)
- 🔵 **Blue** (#6BA3D6): Normal - Healthy usage
- ⚫ **Gray** (#E2E3E5): Unused - 0% usage

## Default Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| SubscriptionNames | (all) | Audit all accessible subscriptions |
| OutputPath | c:\temp | Report output directory |
| OutputFormat | Both | Generate both HTML and CSV |
| HighThreshold | 80 | Warning threshold (%) |
| CriticalThreshold | 90 | Critical threshold (%) |
| IncludeUnused | false | Exclude unused (0%) resources |

## Data Fields Collected

For each quota item:
- Subscription name and ID
- Region/Location
- Resource type (machine name and localized name)
- Current usage count
- Quota limit
- Remaining capacity (calculated)
- Usage percentage (calculated)
- Status classification (calculated)
- Collection timestamp

## Error Handling

The script includes robust error handling for:
- Azure connectivity failures
- Invalid subscription names
- Region query failures
- File I/O operations
- Invalid parameter values

All errors are logged with timestamps and context.

## Prerequisites

**PowerShell Modules:**
```powershell
Install-Module -Name Az.Accounts -Force
Install-Module -Name Az.Compute -Force
```

**Permissions:**
- Reader role across subscriptions to be audited
- Write access to output directory

## Performance Considerations

- **Time:** ~30 seconds to 2 minutes depending on:
  - Number of subscriptions
  - Number of regions (typically 40+)
  - Network latency
  
- **API Calls:** 1 call per subscription + 1 per region per subscription
  
- **Memory:** Scales linearly with resource count (typically minimal)

## Comparison: Original vs Refactored

| Aspect | Original | Refactored |
|--------|----------|-----------|
| Functions | None | 8 dedicated functions |
| Error Handling | None | Comprehensive try-catch |
| Parameters | 0 (hardcoded) | 6 configurable |
| HTML Design | Basic | Professional, modern |
| Logging | Minimal | Structured timestamps |
| Documentation | Limited | Comprehensive |
| Variable Naming | Inconsistent | Clear and consistent |
| Code Quality | Poor | Production-ready |
| Undefined Variables | Yes (`$Corecountrequests`) | All defined |
| Reports | 2 files, hardcoded paths | Timestamped, flexible |
| Authentication | Environment params | Managed identity |
| Azure Automation Ready | No | Yes (built-in) |

## Troubleshooting

### "No subscriptions found"
- Verify Azure authentication: `az account list` or `Get-AzSubscription`
- Authenticate with: `az login` or `Connect-AzAccount`
- Check subscription names match exactly

### "Failed to authenticate to Azure"
- Ensure Azure CLI or PowerShell is authenticated: `az login` or `Connect-AzAccount`
- For Azure Automation: verify the automation account has Reader role on target subscriptions
- Check if managed identity is enabled in Azure Automation

### "AccessDenied" error
- Ensure account has Reader role on subscriptions
- Run `Get-AzSubscription` to verify access
- Try authenticating again: `az login --allow-no-subscriptions`

### "Output directory not found"
- Create the directory first: `New-Item -Path C:\reports -ItemType Directory -Force`
- Ensure write permissions on the directory
- Use the `-OutputPath` parameter to specify a valid location

### "No quota data collected"
- Verify account has Reader role on subscriptions
- Check network connectivity to Azure endpoints
- Verify the Azure Compute API is accessible from your region

### Script runs in Azure Automation but returns no data
- Verify the automation account's managed identity has Reader role
- Assign role: `New-AzRoleAssignment -ObjectId (Get-AzADServicePrincipal -DisplayName 'AutomationAccountName').Id -RoleDefinitionName 'Reader' -Scope '/subscriptions/subscription-id'`
- Check the runbook's System Assigned Identity is enabled

## Notes for Production Use

1. **Schedule as Recurring Task:**
   ```powershell
   # Run daily at 2 AM
   $trigger = New-ScheduledTaskTrigger -Daily -At 2AM
   Register-ScheduledTask -Action (New-ScheduledTaskAction -ScriptBlock {...}) -Trigger $trigger
   ```

2. **Archive Reports:** Move old reports to archive location monthly

3. **CI/CD Integration:** Execute as part of governance automation

4. **Scale-up:** For many subscriptions, parallelize collection using `Foreach-Object -Parallel`

5. **Integration:** Convert JSON output to post to webhook service for dashboards

---

**Version:** 2.0  
**Last Updated:** May 2026  
**Compatibility:** PowerShell 5.1+ with Az.Accounts, Az.Compute modules
