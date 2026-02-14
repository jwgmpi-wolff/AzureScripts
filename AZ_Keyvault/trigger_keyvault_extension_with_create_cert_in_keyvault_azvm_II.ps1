########### Variable settings ########################################

#Define parameters
$resourceGroupName = "wolffextensionrg" 
$storageAccountName = "wolffextensionsa" 
$keyvaultrg = "adminrg" 
$keyvault = "wolffkv" 
$extensionName = "KeyVaultForWindows" 

$subscontext = (connect-azaccount -identity).Context
 #$subscontext = (connect-azaccount).Context
$subscriptions = Get-AzSubscription -SubscriptionName "wolffentpsub"
set-azcontext -subscription $($subscriptions.name) 
########################################################################## $loginContext = Connect-AzAccount -Identity

$certificateAuth = "wolffcertpoc"

az login --identity --scope https://management.core.windows.net//.default

 
##################  Create and add certificate to keyvault ###################################
$Policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName "CN=wolffentp.org" -IssuerName "Self" -ValidityInMonths 6 -ReuseKeyOnRenewal

#Add-AzKeyVaultCertificate -VaultName "$keyvault" -name      "$certificateAuth" -CertificatePolicy $Policy -Verbose
#Get-AzKeyVaultCertificate -VaultName "$keyvault" -name      "$certificateAuth"

####################################

foreach ($sub in $subscriptions) { $subContext = Set-AzContext -Subscription $($sub.Name)



$certKeyVault = Get-AzKeyVault -VaultName "$keyvault" -ResourceGroupName "$keyvaultrg" -SubscriptionId $($subContext.Subscription.Id)

# Retrieve certificate
$certificate = Get-AzKeyVaultCertificate  -VaultName $($certKeyVault.VaultName) -Name $certificateAuth

    $vms = Get-Azvm  
    $vms

    foreach($vm in $vms)
     {

        Write-Host "Checking $($vm.Name)" -ForegroundColor Red -BackgroundColor White

            $Settings = @{
                secretsManagementSettings = @{
                    pollingIntervalInS = "2628000"
                    linkOnRenewal = $true
                    requireInitialSync = $true
                }
                authenticationSettings = @{
                    msiEndpoint = "http://localhost:40342/metadata/identity"
                    msiClientId = "c7373ae5-91c2-4165-8ab6-7381d6e75619"
                }
            }
        $extensionInfo = Get-AzvmExtension -ResourceGroupName $($vm.ResourceGroupName) -vmname     $($vm.Name) | Where-Object { $_.Name -eq "$extensionName" }
        $extensionInfo

        if ($extensionInfo -ne $null) {
            $typeHandlerVersion = "$($extensionInfo.TypeHandlerVersion)"

        
                    Write-Host "$($extensionInfo.Name) $($extensionInfo.Publisher) $($extensionInfo.Version) $($extensionInfo.TypeHandlerVersion)" -ForegroundColor Cyan
                }
                else
                {
                                                                                                                                                                                    if ($extensionInfo -eq $null) {
                Write-Host "$extensionName is not present on $($vm.Name) - Adding" -ForegroundColor Black -BackgroundColor White

                # Get the latest extension details
                $latestExtension = az vm extension image list `
                    --location $($vm.Location) `
                    --query "[?name=='$extensionName'] | sort_by(@, &version) | [-1]" `
                    --output json | ConvertFrom-Json

                if ($latestExtension -eq $null) {
                    $publisher = $latestExtension.publisher
                    $version = $latestExtension.version

                    # Get detailed information about the extension
                    $extensionDetails = az vm extension image show `
                        --location $($vm.Location) `
                        --publisher $publisher `
                        --name      $extensionName `
                        --version $version `
                        --output json | ConvertFrom-Json

                    if ($extensionDetails -ne $null) {
                        # Extract the extension type from the id property
                        $extensionType = ($extensionDetails.id -split '/Types/') -split '/Versions/'

                        # Create a new PSObject to store the extension information
                        $extensionInfoObj = New-Object PSObject
                        $extensionInfoObj | Add-Member -MemberType NoteProperty -name      Name -Value $extensionName
                        $extensionInfoObj | Add-Member -MemberType NoteProperty -name      Publisher -Value $publisher
                        $extensionInfoObj | Add-Member -MemberType NoteProperty -name      TypeHandlerVersion -Value $typeHandlerVersion
                        $extensionInfoObj | Add-Member -MemberType NoteProperty -name      ExtensionType -Value $($extensionType)

                        $extensionInfo = $extensionInfoObj
                 

                        } ### End $extensionDetails
              
                } ## end $latestExtension
        } else {
            Write-Host "Failed to retrieve the latest extension." -ForegroundColor Red
        }
    }
        



        # Re-add and run extension

            Set-AzvmExtension -ResourceGroupName "$($vm.ResourceGroupName)" `
                -Location "$($vm.Location)" `
                -vmname     "$($vm.Name)" `
                -name      "KeyVaultForWindows" `
                -Publisher "$($extensionInfo.Publisher)" `
                -typehandlerversion = "$($extensionInfo.version)" `
                -ExtensionType "KeyVaultForWindows" `
                -Settings $Settings `
                -ForceRerun "true" 
      

    }
}



  $extensionData = ''
# Loop through each virtual machine and get its extensions
foreach ($vm in $vms ) {
    $vmName = $($vm.Name)
    $resourceGroup = $($vm.ResourceGroupName)
    $extensions = Get-azvmextension   -ResourceGroupName $resourceGroup -vmname $vmName  
    foreach ($extension in $extensions) {
        $extensionobj = new-object PSOBject

        $extensionobj | Add-Member -MemberType NoteProperty -name vmname   -value $vmName
        $extensionobj | Add-Member -MemberType NoteProperty -name  ExtensionName  -value $($extension.Name)
        $extensionobj | Add-Member -MemberType NoteProperty -name Publisher   -value   $($extension.Publisher)      
        $extensionobj | Add-Member -MemberType NoteProperty -name Version    -value   $($extension.Version)      
        $extensionobj | Add-Member -MemberType NoteProperty -name ProvisioningState   -value $($extension.ProvisioningState)        
        
       
        [array]$extensionData += $extensionobj

        }
    }
 

# Display the extension data in a table
$extensionData  | ft -AutoSize



