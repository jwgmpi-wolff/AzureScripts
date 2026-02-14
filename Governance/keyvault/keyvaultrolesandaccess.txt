# The script takes care of how identities, both human and non-human, are accessing Azure Key Vaults. 
# It achieves this by auditing two primary access control methods.
# 1. Access Policies (Legacy Method) and 2. Azure RBAC (Recommended Modern Method)
# By combining the analysis of both Access Policies and RBAC roles, the script provides a comprehensive view 
# of how all types of identities are configured to access the Key Vault's secrets, keys, and certificates.
# This allows you to identify where older methods are in use and where you can transition to best practices 
# like using Managed Identities with Azure RBAC.
# Prerequisites: Ensure you have the Az.KeyVault and Az.Accounts modules installed.
# Install-Module -Name Az.KeyVault, Az.Accounts -Force
# Define the output file path and format



$outputFile = "C:\temp\KeyVaultAccessAudit.json"
$report = @()
# Connect to your Azure account
Connect-AzAccount -Identity


$keyvaultaccesslist = ''
# Get all subscriptions you have access to
$subscriptions = Get-AzSubscription
foreach ($sub in $subscriptions) 
{
    Write-Host "Processing Subscription: $($sub.Name) ($($sub.SubscriptionId))" -ForegroundColor Green
    # Select the current subscription
    Set-AzContext -Subscription $($sub.name)
    # Get all Key Vaults in the current subscription
    $keyVaults = Get-AzKeyVault
    foreach ($vault in $keyVaults) {
        $vaultReport = [PSCustomObject]@{
            # Changed the order here: SubscriptionId is now first
            SubscriptionId   = $sub.SubscriptionId
            SubscriptionName = $sub.Name
            KeyVaultName     = $vault.VaultName
            Location         = $vault.Location
            AccessPolicies   = @()
            RBACRoles        = @()
        }
        # --- AUDIT ACCESS POLICIES ---
        $accessPolicies = Get-AzKeyVault -VaultName $vault.VaultName | Select-Object -ExpandProperty AccessPolicies
        if ($accessPolicies) {
            foreach ($policy in $accessPolicies) {
                # Get the display name of the principal
                $principalId = $policy.ObjectId
                $principalName = "Unknown/Deleted Principal"
                try {
                    $principal = Get-AzADServicePrincipal -ObjectId $principalId -ErrorAction SilentlyContinue
                    if (!$principal) {
                        $principal = Get-AzADUser -ObjectId $principalId -ErrorAction SilentlyContinue
                    }
                    if ($principal) {
                        $principalName = $principal.DisplayName
                    }
                }
                catch {}
                $vaultReport.AccessPolicies += [PSCustomObject]@{
                    PrincipalName         = $principalName
                    PrincipalId           = $principalId
                    PermissionsToKeys     = $policy.PermissionsToKeys -join ', '
                    PermissionsToSecrets  = $policy.PermissionsToSecrets -join ', '
                    PermissionsToCertificates = $policy.PermissionsToCertificates -join ', '
                }
            }
        }
        # --- AUDIT AZURE RBAC ROLES ---
        $roleAssignments = Get-AzRoleAssignment -Scope $vault.ResourceId
        if ($roleAssignments) {
            foreach ($role in $roleAssignments) {
                $vaultReport.RBACRoles += [PSCustomObject]@{
                    PrincipalName    = $role.DisplayName
                    PrincipalId      = $role.PrincipalId
                    RoleDefinition   = $role.RoleDefinitionName
                }
            }
        }
        $report += $vaultReport
    }

}






    #####################################################################
 # Initialize HTML content
$html = @"
<html>
<head><title>Key Vault Access Report</title></head>
<body>
<h2>Azure Key Vault Access Report</h2>
<table border='1' cellpadding='5' cellspacing='0'>
<tr>
    <th valign='top'>Subscription ID</th>
    <th valign='top'>Subscription Name</th>
    <th valign='top'>Key Vault Name</th>
    <th valign='top'>Location</th>
    <th valign='top'>Access Policies</th>
    <th valign='top'>RBAC Roles</th>
</tr>
"@


# Loop through the report and build HTML rows
foreach ($vault in $report) {
    $accessPoliciesHtml = if ($vault.AccessPolicies.Count -gt 0) {
        "<ul>" + ($vault.AccessPolicies | ForEach-Object {
            "<li><strong>$($_.PrincipalName)</strong> ($($_.PrincipalId))<br>Keys: $($_.PermissionsToKeys)<br>Secrets: $($_.PermissionsToSecrets)<br>Certificates: $($_.PermissionsToCertificates)</li>"
        }) -join "" + "</ul>"
    } else {
        "None"
    }

    $rbacRolesHtml = if ($vault.RBACRoles.Count -gt 0) {
        "<ul>" + ($vault.RBACRoles | ForEach-Object {
            "<li><strong>$($_.PrincipalName)</strong> ($($_.PrincipalId))<br>Role: $($_.RoleDefinition)</li>"
        }) -join "" + "</ul>"
    } else {
        "None"
    }

    $html += "<tr>
        <td>$($vault.SubscriptionId)</td>
        <td>$($vault.SubscriptionName)</td>
        <td>$($vault.KeyVaultName)</td>
        <td>$($vault.Location)</td>
        <td>$accessPoliciesHtml</td>
        <td>$rbacRolesHtml</td>
    </tr>"
}

# Close HTML
$html += @"
</table>
</body>
</html>
"@

# Save to file
$html | Out-File -FilePath "c:\temp\KeyVaultAccessReport.html" -Encoding UTF8
invoke-item "c:\temp\KeyVaultAccessReport.html"


###############################
# Initialize an array to hold flattened report entries
$csvReport = @()

foreach ($vault in $report) {
    # Flatten Access Policies
    foreach ($policy in $vault.AccessPolicies) {
        $csvReport += [PSCustomObject]@{
            SubscriptionId           = $vault.SubscriptionId
            SubscriptionName         = $vault.SubscriptionName
            KeyVaultName             = $vault.KeyVaultName
            Location                 = $vault.Location
            EntryType                = "AccessPolicy"
            PrincipalName            = $policy.PrincipalName
            PrincipalId              = $policy.PrincipalId
            PermissionsToKeys        = $policy.PermissionsToKeys
            PermissionsToSecrets     = $policy.PermissionsToSecrets
            PermissionsToCertificates= $policy.PermissionsToCertificates
            RoleDefinition           = ""
        }
    }

    # Flatten RBAC Roles
    foreach ($role in $vault.RBACRoles) {
        $csvReport += [PSCustomObject]@{
            SubscriptionId           = $vault.SubscriptionId
            SubscriptionName         = $vault.SubscriptionName
            KeyVaultName             = $vault.KeyVaultName
            Location                 = $vault.Location
            EntryType                = "RBACRole"
            PrincipalName            = $role.PrincipalName
            PrincipalId              = $role.PrincipalId
            PermissionsToKeys        = ""
            PermissionsToSecrets     = ""
            PermissionsToCertificates= ""
            RoleDefinition           = $role.RoleDefinition
        }
    }
}

# Export to CSV
$csvReport | Export-Csv -Path "c:\temp\KeyVaultAccessReport.csv" -NoTypeInformation -Encoding UTF8
