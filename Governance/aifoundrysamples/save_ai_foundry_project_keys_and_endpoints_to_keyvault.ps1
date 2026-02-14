
<#
Final full script (Arc/HybridCompute fix applied)
- Managed Identity sign-in
- Enable KV reachability BEFORE any Get-AzKeyVaultSecret
- Read SP creds from KV (no hard-code), SP login (secret only)
- Grant SPN KV secret permissions
- Store Cognitive Services endpoint + keys
- Re-disable Public Network Access at the end
#>

# =========================
# 0) Modules
# =========================
#Import-Module Az -Force | Out-Null
# Import-Module Microsoft.Graph.Applications -Verbose | Out-Null   # optional; not required for Key Vault/CogSvc ops

# =========================
# 1) Auth: Managed Identity + Subscription context
# =========================
Connect-AzAccount -Identity | Out-Null

$subscriptionName = "wolffentpsub"
$subscription     = Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext -Subscription $subscription.Id | Out-Null

Write-Host ("Connected via Managed Identity. Sub={0} Tenant={1}" -f $subscription.Name, $subscription.TenantId) -ForegroundColor Green

# =========================
# 2) Variables (Key Vault + SPN)
# =========================
$vaultName     = "wolffmlkv"
$resourceGroup = "wolffmlrg"
$spnName       = "wolffaifoundryspn"

# Secrets already stored once in Key Vault (names only; values are retrieved):
$kv_AppId  = "$spnName-client-id"
$kv_Tenant = "$spnName-tenant-id"
$kv_Secret = "$spnName-client-secret"

# =========================
# 3) *** ARC FIX *** Enable KV access BEFORE any reads
# =========================
# Allow Arc/HybridCompute (trusted service) regardless of outbound IP
Update-AzKeyVault -VaultName $vaultName -ResourceGroupName $resourceGroup -PublicNetworkAccess Enabled | Out-Null
Update-AzKeyVaultNetworkRuleSet -VaultName $vaultName -ResourceGroupName $resourceGroup -Bypass AzureServices -DefaultAction Allow | Out-Null

Write-Host "Key Vault temporarily opened (PNA Enabled + AzureServices bypass). Proceeding to read secrets." -ForegroundColor Yellow

# =========================
# 4) Retrieve SPN credentials from Key Vault (NO hard code)
# =========================
$spAppId  = Get-AzKeyVaultSecret -VaultName $vaultName -Name $kv_AppId  -AsPlainText
$spTenant = Get-AzKeyVaultSecret -VaultName $vaultName -Name $kv_Tenant -AsPlainText
$spSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $kv_Secret -AsPlainText

if (-not $spAppId -or -not $spTenant -or -not $spSecret) {
    throw "SPN credentials not found in Key Vault. Missing one of: $kv_AppId / $kv_Tenant / $kv_Secret"
}
Write-Host "Retrieved SPN credentials from Key Vault." -ForegroundColor Cyan

# =========================
# 5) Re-authenticate as the SPN (client secret, NO cert)
# =========================
$secureSecret = ConvertTo-SecureString $spSecret -AsPlainText -Force
$creds        = New-Object System.Management.Automation.PSCredential($spAppId, $secureSecret)

Connect-AzAccount -ServicePrincipal `
  -ApplicationId $spAppId `
  -Tenant        $spTenant `
  -Credential    $creds | Out-Null

Set-AzContext -Subscription $subscription.Id | Out-Null
Write-Host ("Authenticated as SPN '{0}' (AppId={1})." -f $spnName, $spAppId) -ForegroundColor Green

# =========================
# 6) Ensure the SPN can write secrets to Key Vault (data-plane)
# =========================
$spn = Get-AzADServicePrincipal -ApplicationId $spAppId
if (-not $spn) { throw "Service Principal with AppId '$spAppId' not found in Entra ID." }

Set-AzKeyVaultAccessPolicy `
  -VaultName        $vaultName `
  -ResourceGroupName $resourceGroup `
  -ObjectId         $spn.Id `
  -PermissionsToSecrets get,list,set | Out-Null

Write-Host "SPN granted Key Vault secret permissions (get/list/set)." -ForegroundColor Green

# =========================
# 7) Collect Cognitive Services endpoints & keys and store in Key Vault
# =========================
try {
    $aiprojects = Get-AzCognitiveServicesAccount

    foreach ($proj in $aiprojects) {
        $rg   = $proj.ResourceGroupName
        $name = if ($proj.Name) { $proj.Name } else { $proj.AccountName }

        $acct     = Get-AzCognitiveServicesAccount -ResourceGroupName $rg -Name $name
        $endpoint = $acct.Endpoint

        $keys     = Get-AzCognitiveServicesAccountKey -ResourceGroupName $rg -Name $name   # returns Key1/Key2

        $tags = @{
            ResourceGroup = $rg
            Location      = $acct.Location
            Kind          = $acct.Kind
            Source        = "CognitiveServices"
        }

        # Secret names
        $secretEndpoint = "$name-endpoint"
        $secretKey1     = "$name-key1"
        $secretKey2     = "$name-key2"

        # Write/update
        Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretEndpoint -SecretValue (ConvertTo-SecureString $endpoint   -AsPlainText -Force) -Tag $tags -ContentType "text/plain" | Out-Null
        Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretKey1     -SecretValue (ConvertTo-SecureString $keys.Key1 -AsPlainText -Force) -Tag $tags -ContentType "text/plain" | Out-Null
        Set-AzKeyVaultSecret -VaultName $vaultName -Name $secretKey2     -SecretValue (ConvertTo-SecureString $keys.Key2 -AsPlainText -Force) -Tag $tags -ContentType "text/plain" | Out-Null

        Write-Host ("Stored in KV: {0} endpoint + keys" -f $name) -ForegroundColor Magenta
    }

} finally {
    # =========================
    # 8) Final auto-lockdown: re-disable Public Network Access
    # =========================
    Update-AzKeyVault -VaultName $vaultName -ResourceGroupName $resourceGroup -PublicNetworkAccess enabled | Out-Null
    Write-Host ("Key Vault '{0}' re-locked (PNA Disabled). Script completed." -f $vaultName) -ForegroundColor Green
}
