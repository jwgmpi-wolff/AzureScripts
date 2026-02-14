 <#
.NOTES

    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 

    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 

    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 

    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all

    implied warranties including, without limitation, any implied warranties of merchantability

    or of fitness for a particular purpose. The entire risk arising out of the use or performance

    of the sample and documentation remains with you. In no event shall Microsoft, its authors,

    or anyone else involved in the creation, production, or delivery of the script be liable for 

    any damages whatsoever (including, without limitation, damages for loss of business profits, 

    business interruption, loss of business information, or other pecuniary loss) arising out of 

    the use of or inability to use the sample or documentation, even if Microsoft has been advised 

    of the possibility of such damages, rising out of the use of or inability to use the sample script, 

    even if Microsoft has been advised of the possibility of such damages.

    Purpose
        The purpose of this Azure PowerShell script is to automate the process of managing VM extensions across 
        multiple subscriptions. Specifically,
         it retrieves a certificate from Azure Key Vault and ensures that a specified VM extension is installed 
         and configured on all VMs within the subscriptions.

        Description
        Define Parameters: Sets up necessary parameters such as resource group names, storage account names, 
        key vault names, and extension names.
        Authenticate and Set Context: Authenticates using managed identity and sets the Azure context for the
         specified subscriptions.
        Retrieve Certificate: Retrieves a specified certificate from Azure Key Vault.
        List VMs: Retrieves a list of all VMs in the current subscription.
        Check and Configure Extensions:
        For each VM, checks if the specified extension is already installed.
        If the extension is not present, retrieves the latest extension details and installs the extension with
         the necessary settings.
        If the extension is present, reconfigures it with the updated settings.
        Settings Configuration: Configures the extension settings to manage certificates and authentication settings.
        This script ensures that all VMs across multiple subscriptions have the specified VM extension installed and 
        configured with the latest settings, including certificate management from Azure Key Vault.

Name: trigger_certificate_extension_to_keyvault

#>
  
 
 

# Define parameters
$resourceGroupName = "wolffextensionrg"
$storageAccountName = "wolffextensionsa"
$keyvaultrg = "adminrg"
$keyvault = "wolffkv"
 $extensionname = "KVVMExtensionForWindows" 
#$extensionname = "AdminCenter"

$subscriptions = get-azsubscription -subscriptionname wolffentpsub

$logincontext =  Connect-AzAccount  -Identity 

$certificateauth = "wolffautomationsp"

 az login --identity --scope https://management.core.windows.net//.default

 set-azcontext -Tenant  $($logincontext.Context.Tenant.TenantId) -Subscription $($logincontext.Context.Subscription.Name)


foreach($sub in $subscriptions) 
{
 
  

     $subcontext =   set-azcontext -subscription $($sub.name) 
                

               $certkeyvault =  Get-AzKeyVault -VaultName "$keyvault" -ResourceGroupName "$keyvaultrg"  -SubscriptionId $($subcontext.Subscription.Id)

   
                ### retrieve certificate

                    $certificate = Get-AzKeyVaultSecret -VaultName $($certkeyvault.vaultname) -name $certificateauth  

                    # Get the plain text certificate from the secure string

                             #$certificateplaintext = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($certificate))

                              #Get-AzKeyVaultsecret -VaultName "$keyVaultName" -Name "$($certificateauth.certificate)"  -AsPlainText

    $vmslist = get-azvm 


        foreach($vm in $vmslist)
        {

            write-host "Checking $($Vm.name)" -ForegroundColor red -BackgroundColor white

                $Settings = @{
                  secretsManagementSettings = @{
                    observedCertificates = @(
                      "https://$certkeyvault.vault.azure.net/secrets/$certificate"
                      # Add more here, don't forget a comma on the preceding line
                    )
                    # The cert store location is optional, the default path is shown below
                    # certificateStoreLocation = "/var/lib/waagent/Microsoft.Azure.KeyVault.Store/"
                    #pollingIntervalInS = "3600" # every hour
                  }
                  authenticationSettings = @{
                    msiEndpoint = "http://localhost:40342/metadata/identity"
                  }
                }  # end of settings 
                ($settings.values).getenumerator() | ForEach-Object {

                        Write-Host "$($vm.name) - $($_.msiEndpoint) - $($_.observedCertificates) - $($certicate.name)  " -foregroundcolor cyan

                }
 

          $extensioninfo =   Get-AzVMExtension -ResourceGroupName $($vm.ResourceGroupName) -VMName $($vm.name) -Status | Where name -eq "$extensionname"
           $extensioninfo
           if($extensioninfo -ne $null) 
           {
             $typeHandlerversion = "$($extensioninfo.typeHandlerversion)"
           }

          write-host "$($extensioninfo.name) $($extensioninfo.publisher) $($extensioninfo.version)  $($extensioninfo.TypeHandlerVersion)" -ForegroundColor Cyan

                if ($extensioninfo -eq $null) {
                    Write-Host " $extensionName is not present on $($vm.Name) - Adding " -ForegroundColor black -BackgroundColor white

                    # Get the latest extension details
                    $latestExtension = az vm extension image list `
                        --location $($vm.location) `
                        --query "[?name=='$extensionName'] | sort_by(@, &version) | [-1]" `
                        --output json | ConvertFrom-Json

                    $publisher = $latestExtension.publisher
                    $version = $latestExtension.version

                    # Get detailed information about the extension
                    $extensionDetails = az vm extension image show `
                        --location $($vm.location) `
                        --publisher $publisher `
                        --name $extensionName `
                        --version $version `
                        --output json | ConvertFrom-Json

                    # Extract the extension type from the id property
                    $extensionType = ($extensionDetails.id -split '/Types/')[1] -split '/Versions/'[0]

                    # Create a new PSObject to store the extension information
                    $extensioninfoobj = New-Object PSObject

                    $extensioninfoobj | Add-Member -MemberType NoteProperty -Name Name -Value $extensionName
                    $extensioninfoobj | Add-Member -MemberType NoteProperty -Name Publisher -Value $publisher
                    $extensioninfoobj | Add-Member -MemberType NoteProperty -Name TypeHandlerVersion -Value $typeHandlerversion
                    $extensioninfoobj | Add-Member -MemberType NoteProperty -Name ExtensionType -Value $($extensionType[0])

                    $extensioninfo = $extensioninfoobj
                }
            

     

        ## re-add and run extension

                 Set-AzVMExtension -ResourceGroupName "$($vm.resourcegroupname)" `
                 -Location "$($vm.location)" `
                 -VMName "$($vm.name)" `
                 -Name "$($extensioninfo.name)" `
                 -Publisher "$($extensioninfo.publisher)"  `
                 -ExtensionType "$($extensioninfo.ExtensionType)" `
                 -TypeHandlerVersion "$($extensioninfo.TypeHandlerVersion)" `
                 -Settings $Settings `
                 -ForceRerun $true
             
              

         } # end ov vmlist 

} ### End of subscription loop



















