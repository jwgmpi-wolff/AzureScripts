connect-azaccount -Identity

$keyvaultrg = "adminrg" 
$keyvault = "wolffkv" 

$certificateAuth = "wolffcertpoc"

$certificate = Get-AzKeyVaultSecret -VaultName "$keyvault" -Name "$certificateAuth"   -AsPlainText
$thumbprinttocheck  = Get-AzKeyVaultCertificate -VaultName "$keyvault" -Name "$certificateAuth"
$certificateThumbprint = $($certificate.SecretValue)
$localCertificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $($thumbprinttocheck.Thumbprint) }
$localCertificate


 Get-ChildItem -Path Cert:\LocalMachine\My  


