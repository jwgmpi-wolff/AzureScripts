      #################################
            # Retrieve certificate from Azure Key Vault
            $certKeyVault = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName
            $certificatesecret = Get-AzKeyVaultSecret -VaultName $certKeyVault.VaultName -Name $certificateAuth -AsPlainText
            $certBytes = [Convert]::FromBase64String($certificatesecret)

            # Write the certificate to a file
            $certFilePath = "C:\LocalMachine\My\cert.pfx"
            [System.IO.File]::WriteAllBytes($certFilePath, $certBytes)
 

                    $certBytes = [Convert]::FromBase64String($certificatesecret)

 

                            # Import the certificate to the LocalMachine\My store
                            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                            $cert.Import($certBytes)
                            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
                            $store.Open("ReadWrite")
                            $store.Add($cert)
                            $store.Close()

                            $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $certThumbprint }

                    if ($cert) {
                        Write-Host "Certificate is present on VM: $($using:vm.Name)" -ForegroundColor Green
                    } else {
                        Write-Host "Certificate is not present on VM: $($using:vm.Name)" -ForegroundColor Red
                    }


<#
  
 
  $keyvaultrg = "adminrg" 
$keyvault = "wolffkv" 
$extensionName = "KeyVaultForWindows" 

$subscontext = (connect-azaccount -identity).Context

$subscriptions = Get-AzSubscription -SubscriptionName "wolffentpsub" 
 $certificateAuth = "wolffcertpoc"  
   
   
   
# Retrieve certificate from Azure Key Vault
$certKeyVault = Get-AzKeyVault -VaultName $keyvault -ResourceGroupName $keyvaultrg
$certificatesecret = Get-AzKeyVaultSecret -VaultName $certKeyVault.VaultName -Name $certificateAuth -AsPlainText
$certBytes = [Convert]::FromBase64String($certificatesecret)

 

        # Import the certificate to the LocalMachine\My store
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($certBytes)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
        $store.Open("ReadWrite")
        $store.Add($cert)
        $store.Close()

        $cert = Get-ChildItem Cert:\LocalMachine\My 
#>
 