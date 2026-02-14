# ===========================
# CONFIGURATION
# ===========================
$tenantId = "653eac6f-6d25-42f6-8cfa-a01bb45ab2dc"
$subscriptionName = "wolffofficesub"
$spnName = "wolffTeamsCallingBot"
$vaultName = "wolffofficekvkv2"
$secretName = "wolffTeamsBotSecret"

# ===========================
# CONNECT TO AZURE
# ===========================
#Connect-AzAccount -Tenant $tenantId
$subscription = Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext -Subscription $subscription.Id

# Connect to Microsoft Graph with required scopes
Connect-MgGraph -Scopes "Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All","Directory.ReadWrite.All"

# ===========================
# CREATE SERVICE PRINCIPAL
# ===========================
Write-Host "Creating Service Principal: $spnName" -ForegroundColor Cyan
$sp = New-AzADServicePrincipal -DisplayName $spnName
Write-Host "✅ Created SPN: $($sp.DisplayName) | AppId: $($sp.AppId)"

# ===========================
# CREATE CLIENT SECRET (NO HARDCODE)
# ===========================
$secret = New-AzADAppCredential -ObjectId $sp.AppId -EndDate (Get-Date).AddYears(1)
$clientSecret = $secret.SecretText
Write-Host "✅ Generated client secret (valid for 1 year)"

# ===========================
# STORE SECRET IN KEY VAULT
# ===========================
Write-Host "Storing secret in Key Vault: $vaultName" -ForegroundColor Cyan
Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -SecretValue (ConvertTo-SecureString $clientSecret -AsPlainText -Force)
Write-Host "✅ Secret stored in Key Vault as $secretName"

# ===========================
# ASSIGN MICROSOFT GRAPH APP ROLES
# ===========================
Write-Host "Assigning Microsoft Graph API roles..." -ForegroundColor Cyan

# Get Microsoft Graph Service Principal
$graphSp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

# Permissions to assign
$permissions = @(
    "Calls.AccessMedia.All",
    "Calls.JoinGroupCall.All",
    "Calls.JoinGroupCallAsGuest.All",
    "OnlineMeetings.Read.All",
    "User.Read.All"
)

foreach ($perm in $permissions) {
    $appRole = $graphSp.AppRoles | Where-Object {
        $_.Value -eq $perm -and $_.AllowedMemberTypes -contains "Application"
    }

    if ($appRole) {
        New-MgServicePrincipalAppRoleAssignment `
            -ServicePrincipalId $sp.Id `
            -PrincipalId $sp.Id `
            -ResourceId $graphSp.Id `
            -AppRoleId $appRole.Id

        Write-Host "✅ Assigned $perm"
    } else {
        Write-Warning "⚠️ Permission $perm not found in Microsoft Graph SPN AppRoles"
    }
}

# ===========================
# OUTPUT SPN DETAILS
# ===========================
Write-Host "`nSPN Details:" -ForegroundColor Green
Write-Host "Tenant ID: $tenantId"
Write-Host "App ID (Client ID): $($sp.AppId)"
Write-Host "Client Secret: Stored in Key Vault ($vaultName/$secretName)"
Write-Host "Object ID: $($sp.Id)"