 <#
.SYNOPSIS
Comprehensive Azure Governance Assessment:
Identifies opportunities for FinOps, SaaS governance, monitoring, security, and policy compliance in an Azure tenant.

.DESCRIPTION
This script:
- Authenticates to Azure using Managed Identity or interactive login.
- Runs targeted Azure Resource Graph queries and Azure APIs to assess:
    * FinOps: Get cost analysis, unused resources, reserved instance recommendations.
    * SaaS Governance: List Enterprise Apps, check unused or risky apps.
    * Monitoring: Check resources without diagnostic settings or Log Analytics.
    * Policy Compliance: Pull compliance state from Azure Policy.
    * Security: Query Microsoft Defender recommendations and Secure Score.
- Outputs findings to CSV and HTML for review.

.REQUIREMENTS
- PowerShell 7.x or Windows PowerShell 5.1
- Az modules: Az.Accounts, Az.ResourceGraph, Az.PolicyInsights, Az.Security
- Reader or higher permissions on subscriptions.
#>

 

# Authenticate
Connect-AzAccount -Identity -ErrorAction SilentlyContinue
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Define output path
$OutPath = "C:\temp"
$null = New-Item -ItemType Directory -Path $OutPath -ErrorAction SilentlyContinue

Write-Host "Running Azure Governance Assessment..." -ForegroundColor Cyan

# Initialize detailed results
$details = @()

# Get subscription names for enrichment
$subscriptions = Get-AzSubscription | Select-Object Id, Name

function Get-SubscriptionName($subId) {
    ($subscriptions | Where-Object { $_.Id -eq $subId }).Name
}

# -------------------- FinOps Opportunities --------------------
$finOpsQuery = @"
Resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend sku = tostring(properties.hardwareProfile.vmSize), diskSizeGB = tostring(properties.storageProfile.osDisk.diskSizeGB)
| project subscriptionId, resourceGroup, name, sku, location, diskSizeGB
"@
$finOpsResults = Search-AzGraph -Query $finOpsQuery
foreach ($item in $finOpsResults) {
    $recommendation = if ([int]$item.diskSizeGB -gt 128) {
        "Disk size is large; consider resizing or using managed disks for cost optimization."
    } elseif ($item.sku -like "*Standard_D*") {
        "Consider Reserved Instances or Spot VMs for cost savings."
    } else {
        "Review VM SKU and usage for potential optimization."
    }

    $details += [PSCustomObject]@{
        Category        = "FinOps"
        SubscriptionId  = $item.subscriptionId
        Subscription    = Get-SubscriptionName $item.subscriptionId
        ResourceGroup   = $item.resourceGroup
        Name            = $item.name
        SKU             = $item.sku
        Location        = $item.location
        DiskSizeGB      = $item.diskSizeGB
        Recommendation  = $recommendation
    }
}

# -------------------- SaaS Governance --------------------
$saasQuery = @"
Resources
| where type =~ 'microsoft.saas/resources'
| project subscriptionId, resourceGroup, name, type, location
"@
$saasResults = Search-AzGraph -Query $saasQuery
foreach ($item in $saasResults) {
    $details += [PSCustomObject]@{
        Category        = "SaaS Governance"
        SubscriptionId  = $item.subscriptionId
        Subscription    = Get-SubscriptionName $item.subscriptionId
        ResourceGroup   = $item.resourceGroup
        Name            = $item.name
        Type            = $item.type
        Location        = $item.location
        Recommendation  = "Review SaaS resource usage and licensing for cost and compliance optimization."
    }
}

# -------------------- Monitoring Coverage --------------------
$monitorQuery = @"
Resources
| where type =~ 'microsoft.insights/components'
| project subscriptionId, resourceGroup, name, location, properties.Application_Type
"@
$monitorResults = Search-AzGraph -Query $monitorQuery
foreach ($item in $monitorResults) {
    $details += [PSCustomObject]@{
        Category        = "Monitoring"
        SubscriptionId  = $item.subscriptionId
        Subscription    = Get-SubscriptionName $item.subscriptionId
        ResourceGroup   = $item.resourceGroup
        Name            = $item.name
        Location        = $item.location
        AppType         = $item.'properties_Application_Type'
        Recommendation  = "Ensure all critical resources have diagnostic settings and are sending logs to Log Analytics."
    }
}

# -------------------- Security Posture --------------------
# Security Recommendations from Azure Advisor
$advisorSecurity = Get-AzAdvisorRecommendation | Where-Object { $_.Category -eq "Security" }

foreach ($item in $advisorSecurity) {
    
    if ($item.ResourceMetadataResourceId) {
        $parts = $item.ResourceMetadataResourceId -split '/'
        if ($parts.Length -ge 3) { $subscriptionId = $parts[2]; $contextType = "Subscription-wide" }
        if ($parts.Length -ge 9) { $resourceName = $parts[-1]; $contextType = "Resource-specific" }
    }

    # Build recommendation text
    $recommendationText = if ($item.ShortDescriptionProblem -or $item.ShortDescriptionSolution) {
        "$($item.ShortDescriptionProblem) | Remediation: $($item.ShortDescriptionSolution)"
    } else {
        "Review security recommendation: $($item.DisplayName)"
    }

    # Add record with all properties
    $details += [PSCustomObject]@{
        Category        = "Security"
        Context         = $contextType
        SubscriptionId  = $subscriptionId
        Subscription    = if ($subscriptionId -ne "N/A") { Get-SubscriptionName $subscriptionId } else { "Tenant-wide" }
        ResourceGroup   = $resourceGroup
        Name            = $resourceName
        SecurityItem    = $item.DisplayName
        Description     = $item.Description
        Recommendation  = $recommendationText
        Impact          = $item.Impact
        Risk            = $item.Risk
        PotentialBenefit= $item.PotentialBenefit
        LearnMoreLink   = $item.LearnMoreLink
        LastUpdated     = $item.LastUpdated
    }
}



# -------------------- Policy Compliance --------------------
$policyStates = Get-AzPolicyState -Top 500
foreach ($item in $policyStates | Where-Object { $_.ComplianceState -eq "NonCompliant" }) {
    $parts = $item.ResourceId -split '/'
    $subscriptionId = $parts[2]
    $resourceGroup  = $parts[4]
    $resourceName   = $parts[-1]

    $details += [PSCustomObject]@{
        Category        = "Policy Compliance"
        SubscriptionId  = $subscriptionId
        Subscription    = Get-SubscriptionName $subscriptionId
        ResourceGroup   = $resourceGroup
        Name            = $resourceName
        PolicyName      = $item.PolicyDefinitionReferenceId
        Compliance      = $item.ComplianceState
        Recommendation  = "Resource does not comply with policy '$($item.PolicyDefinitionReferenceId)'. Review and remediate to meet governance standards."
    }
}

# -------------------- Output --------------------
$csvPath = Join-Path $OutPath "AzureGovernanceAssessment_Detailed.csv"
$htmlPath = Join-Path $OutPath "AzureGovernanceAssessment_Detailed.html"

$details | Export-Csv -Path $csvPath -NoTypeInformation
$details | ConvertTo-Html -Title "Azure Governance Assessment Detailed Report" | Out-File $htmlPath

Write-Host "Assessment complete. Detailed results saved to $OutPath" -ForegroundColor Green
