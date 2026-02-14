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
foreach ($sub in $subscriptions) {
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


foreach($access in $report)
{

                   

     foreach($accessitem in   $report.accesspolicies )
     {
                    foreach($rbacrole in $($access.RBACRoles) )
                    {
 $accessobj = new-object PSOBject 

                    $accessobj | Add-Member -MemberType NoteProperty -Name  SubscriptionId    -value $($access.SubscriptionId)
                    $accessobj | Add-Member -MemberType NoteProperty -Name  SubscriptionName    -value $($access.SubscriptionName)
                    $accessobj | Add-Member -MemberType NoteProperty -Name  KeyVaultName    -value  $($access.KeyVaultName)
                    $accessobj | Add-Member -MemberType NoteProperty -Name  Location   -value  $($access.Location)
   

     

                    $accessobj | Add-Member -MemberType NoteProperty -Name PrincipalName  -Value $($accessitem.PrincipalName)
                    $accessobj | Add-Member -MemberType NoteProperty -Name PrincipalId -Value $($accessitem.PrincipalId)     
                    $accessobj | Add-Member -MemberType NoteProperty -Name PermissionsToKeys -Value $($accessitem.PermissionsToKeys)
                    $accessobj | Add-Member -MemberType NoteProperty -Name PermissionsToSecrets -Value $($accessitem.PermissionsToSecrets)
                    $accessobj | Add-Member -MemberType NoteProperty -Name PermissionsToCertificates -Value $($accessitem.PermissionsToCertificates)

    

                   $accessobj | Add-Member -MemberType NoteProperty -Name RBACROLESprincipal -Value $($rbacrole.principalname)
                   
 

                   $accessobj | Add-Member -MemberType NoteProperty -Name RBACROLESRoleDefinition -Value $($rbacrole.RoleDefinition)
                   
 

                   }

    }

    [array]$keyvaultaccesslist += $accessobj

     


}

 $keyvaultaccesslist

}
# Convert the PowerShell object to JSON and save it to the file
$report | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputFile
Write-Host "Audit completed. Output saved to: $outputFile" -ForegroundColor Green 


 

# Generate HTML Report
$CSS = @"
<style>
th {
    font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
    color: #FFFFFF;
    background: #5F9EA0;
    padding: 6px;
}
td {
    font: 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
    color: #0000FF;
    background: #fff;
    padding: 6px;
}
</style>
"@

$keyvaultaccessreport =  $keyvaultaccesslist | select SubscriptionId,`
SubscriptionName,`
KeyVaultName,`
Location,`
PrincipalName,`
PrincipalId,`
PermissionsToKeys,`
PermissionsToSecrets,`
PermissionsToCertificates,`
RBACROLESprincipal,`
RBACROLESPrincipalId,`
RBACROLESRoleDefinition `
| ConvertTo-Html -Head $CSS -Title "kEYVAULT access AUDIT"


$keyvaultaccessreport | Out-File "C:\temp\keyvaultaccessreport.html"
Invoke-Item "C:\temp\keyvaultaccessreport.html"

 
 $keyvaultaccessreport | select  select SubscriptionId,`
SubscriptionName,`
KeyVaultName,`
Location,`
PrincipalName,`
PrincipalId,`
PermissionsToKeys,`
PermissionsToSecrets,`
PermissionsToCertificates,`
RBACROLESprincipal,`
RBACROLESPrincipalId,`
RBACROLESRoleDefinition  | export-csv   c:\temp\keyvaultaccessreport.csv -NoTypeInformation


