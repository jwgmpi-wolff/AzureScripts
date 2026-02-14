
# Requires: Az.Accounts, Az.Resources, Az.KeyVault, Az.Directory
# LOCAL MACHINE variant: interactive or SP login (Managed Identity does NOT exist locally)

# =========================
# INPUTS
# =========================
$SubscriptionNameOrId = "wolffentpsub"
$vaultname            = "wolffmlkv"
$VaultResourceGroup   = "wolffmlrg"

$spnname              = "wolffaifoundryspn"   # Detect by DisplayName (exact)
$SecretYears          = 1                     # New client secret validity

# Secret names derived from $spnname
$SecretName_ClientId  = "$spnname-client-id"
$SecretName_Secret    = "$spnname-client-secret"   # <-- the Key Vault entry we check/add
$SecretName_TenantId  = "$spnname-tenant-id"

# =========================
# AUTH & CONTEXT (LOCAL)
# =========================
Connect-AzAccount -Identity

Set-AzContext -Subscription $SubscriptionNameOrId

$tenant = (Get-AzTenant | Select-Object -First 1)

# =========================
# HELPERS
# =========================
function Get-ExistingServicePrincipal {
    param([string]$DisplayName)
    $candidates = Get-AzADServicePrincipal -DisplayName $DisplayName -ErrorAction SilentlyContinue
    $exact = $candidates | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
    return $exact
}

function New-AppSecret {
    param([string]$ApplicationId, [int]$Years = 1)
    $start = Get-Date
    $end   = $start.AddYears($Years)
    # Create password credential for the application
    $cred = New-AzADAppCredential -ApplicationId $ApplicationId -StartDate $start -EndDate $end  # [2](https://microsoft-my.sharepoint.com/personal/jerrywolff_microsoft_com/Documents/Documents/WindowsPowerShell/Modules/Az.KeyVault/6.3.1/Microsoft.Azure.PowerShell.Cmdlets.KeyVault.dll-Help.xml?web=1)
    return $cred
}

function Ensure-SecretString {
    param([string]$VaultName, [string]$SecretName, [string]$PlainValue, [hashtable]$Tags)
    # If secret exists with same value, skip writing a new version
    try {
        $existing    = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -ErrorAction Stop
        $existingVal = Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText -ErrorAction Stop
        if ($existingVal -eq $PlainValue) {
            return @{ Updated=$false; Reason="No change"; Version=$existing.Version }
        }
    } catch { }
    $sec = ConvertTo-SecureString -String $PlainValue -AsPlainText -Force
    $set = Set-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue $sec -Tag $Tags -ContentType "text/plain"  # [3](https://support.microsoft.com/en-us/topic/189a8605-61dc-deec-d121-1da02731057b)
    return @{ Updated=$true; Reason="Set new value"; Version=$set.Version }
}

function Ensure-KvAccessPolicyForCurrentPrincipal {
    param([string]$VaultName)
    $acct = Get-AzContext
    $u = Get-AzADUser -UserPrincipalName $acct.Account.Id -ErrorAction SilentlyContinue
    $objId = $null
    if ($u) { $objId = $u.Id }
    else {
        try {
            $spSelf = Get-AzADServicePrincipal -ApplicationId $acct.Account.Id -ErrorAction Stop
            $objId = $spSelf.Id
        } catch { }
    }
    if (-not $objId) { return $false }

    $kv = Get-AzKeyVault -VaultName $VaultName
    $hasPolicy = $false
    if ($kv.AccessPolicies) {
        $hasPolicy = $kv.AccessPolicies | Where-Object {
            $_.ObjectId -eq $objId -and $_.PermissionsToSecrets -and ($_.PermissionsToSecrets -contains "Set")
        } | ForEach-Object { $true } | Select-Object -First 1
    }
    if ($hasPolicy) { return $false }

    Set-AzKeyVaultAccessPolicy -VaultName $VaultName -ObjectId $objId -PermissionsToSecrets get,list,set | Out-Null  # 
    return $true
}

function Add-IpToKeyVaultIfMissing {
    param([string]$VaultName, [string]$ResourceGroupName, [string]$IpCidr)
    $kv = Get-AzKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroupName
    $current = @()
    if ($kv.NetworkAcls.IpRules) { $current = $kv.NetworkAcls.IpRules.IpAddressOrRange }
    if ($current -contains $IpCidr) { return $false }
    $updated = @($current + $IpCidr) | Select-Object -Unique
    Update-AzKeyVaultNetworkRuleSet -VaultName $VaultName -ResourceGroupName $ResourceGroupName -IpAddressRange $updated -DefaultAction Deny | Out-Null  # 
    return $true
}

function Test-KvSecretExists {
    param(
        [Parameter(Mandatory)] [string] $VaultName,
        [Parameter(Mandatory)] [string] $SecretName
    )
    try {
        # Ask for versions; if none come back, it truly doesn't exist
        $versions = Get-AzKeyVaultSecret -VaultName $VaultName `
                                         -Name $SecretName `
                                         -IncludeVersions `
                                         -Maxresults 1 `
                                         -ErrorAction Stop
        return ($null -ne $versions)
    }
    catch {
        # Try to read HTTP status when available (KeyVaultErrorException)
        }
    }

# =========================
# KEY VAULT REACHABILITY (LOCAL)
# =========================
# Enable Public Network Access while writing from local (you can disable after run)#
#Update-AzKeyVault -VaultName $vaultname -ResourceGroupName $VaultResourceGroup -PublicNetworkAccess Enabled | Out-Null  # 

###### update from arc enabled computer 

Update-AzKeyVaultNetworkRuleSet `
   -VaultName $vaultname `
   -Bypass AzureServices `
   -DefaultAction allow

###########################

<## Add your /32 if not present
$myIp    = (Invoke-RestMethod "https://api.ipify.org?format=json").ip
$addedIp = Add-IpToKeyVaultIfMissing -VaultName $vaultname -ResourceGroupName $VaultResourceGroup -IpCidr "$myIp/32"
if ($addedIp) { Write-Host "✅ Added $myIp/32 to KV firewall." } else { Write-Host "ℹ️ IP already present." }

# Allow trusted Azure services to bypass (optional)
Update-AzKeyVaultNetworkRuleSet -VaultName $vaultname -Bypass AzureServices | Out-Null  # 

# Ensure your current principal has secrets permissions
$addedPolicy = Ensure-KvAccessPolicyForCurrentPrincipal -VaultName $vaultname
if ($addedPolicy) { Write-Host "✅ Granted secrets set/get/list to current principal." }
#>
# =========================
# MAIN: detect $spnname, ensure secret in KV
# =========================
$sp = Get-ExistingServicePrincipal -DisplayName $spnname
if (-not $sp) {
    Write-Warning "Service Principal with display name '$spnname' not found. No changes made."
    return
}

Write-Host ("Found SP: DisplayName={0} AppId={1} ObjectId={2}" -f $sp.DisplayName, $sp.AppId, $sp.Id)

# Check if the client secret entry already exists in Key Vault

$secretExists = Test-KvSecretExists -VaultName $vaultname -SecretName $SecretName_Secret
if ($secretExists) {
    Write-Host "Secret exists: $SecretName_Secret"
} else {
    Write-Host "Secret does not exist: $SecretName_Secret"

 


    # Create a new client secret for the application (password credential)
    $newCred = New-AppSecret -ApplicationId $sp.AppId -Years $SecretYears  # [2](https://microsoft-my.sharepoint.com/personal/jerrywolff_microsoft_com/Documents/Documents/WindowsPowerShell/Modules/Az.KeyVault/6.3.1/Microsoft.Azure.PowerShell.Cmdlets.KeyVault.dll-Help.xml?web=1)

    # Build tags for governance
    $tags = @{
        Purpose = "SPN-Automation"
        Display = $sp.DisplayName
        KeyId   = ($newCred.KeyId | Out-String).Trim()
        EndDate = "$($newCred.EndDate)"
    }

    # Store ClientId, TenantId, and the new Secret in KV (skip-dup check for ClientId/TenantId)
    $cid = Ensure-SecretString -VaultName $vaultname -SecretName $SecretName_ClientId -PlainValue $sp.AppId        -Tags $tags
    $tid = Ensure-SecretString -VaultName $vaultname -SecretName $SecretName_TenantId -PlainValue $tenant.TenantId -Tags $tags
    $sid = Ensure-SecretString -VaultName $vaultname -SecretName $SecretName_Secret   -PlainValue $newCred.SecretText -Tags $tags
    Write-Host "✅ Stored: ClientId($($cid.Reason)), TenantId($($tid.Reason)), Secret($($sid.Reason))."
}

Write-Host "🏁 Done."
