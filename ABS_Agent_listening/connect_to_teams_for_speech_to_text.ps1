# ===========================
# CONFIGURATION
# ===========================
  
$botPackagePath = "C:\temp\publish"  # Path to published C# bot
$joinUrl =  "https://teams.microsoft.com/meet/2366523601842?p=tL05X4KDSPFxYm6sZW"
$keyVaultUri = "https://wolffofficekvkv2.vault.azure.net/"
 
$speechRegion = "westus"
$tenantId = "653eac6f-6d25-42f6-8cfa-a01bb45ab2dc"
 
$vaultName = "wolffofficekvkv2"
$spnName = "wolffTeamsCallingBot"
$resourceGroup = "wolffteamsagentrg"
$speechResourceName = "wolffspeechsvc"

$appId = (Get-MgApplication -Filter "DisplayName eq '$spnName'").AppId
$appSecret = (Get-AzKeyVaultSecret -VaultName $vaultName -Name $appId -AsPlainText)
$speechKey = (Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroup -Name $speechResourceName).Key1
$speechRegion = (Get-AzCognitiveServicesAccount -ResourceGroupName $resourceGroup -Name $speechResourceName).Location

# ===========================
# DEPLOY BOT TO AZURE APP SERVICE
# ===========================
Write-Host "Deploying bot to Azure App Service..." -ForegroundColor Cyan
Publish-AzWebApp -ResourceGroupName $resourceGroup -Name $spnName -ArchivePath "$botPackagePath\bot.zip"

# ===========================
# CONFIGURE ENVIRONMENT VARIABLES
# ===========================
Write-Host "Configuring environment variables..." -ForegroundColor Cyan
$settings = @{
    "JOIN_URL"      = $joinUrl
    "KEYVAULT_URI"  = $keyVaultUri
    "SPEECH_KEY"    = $speechKey
    "SPEECH_REGION" = $speechRegion
    "TENANT_ID"     = $tenantId
    "CLIENT_ID"     = $appId
}

foreach ($key in $settings.Keys) {
    Set-AzWebApp -ResourceGroupName $resourceGroup -Name $spnName -AppSettings @{ $key = $settings[$key] }
}

Write-Host "✅ Bot deployed and configured. It will join the Teams meeting using the Join URL."