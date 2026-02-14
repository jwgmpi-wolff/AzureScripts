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

Name: create_spn_and_save_secret_to_keyvault_interactive.ps1
 
 
 Purpose/Description he provided PowerShell script serves the purpose of managing Azure resources and service principals across multiple tenants. Let’s break down its functionality:

Connecting to Azure Context:
The script begins by connecting to the Azure context based on login credentials using the connect-azaccount command.
If the -Identity parameter is used with connect-azaccount, the managed identity will be used for context during execution.
For Azure Government tenants, the script recommends using connect-azconnect -Environment AzureUSGovernment.
Access Token Retrieval:
The script retrieves an access token for a specified resource URL using Get-AzAccessToken.
It also retrieves an access token for a specified tenant ID using the same command.
Listing Tenants:
The script lists all available tenants using get-aztenant.
It allows the user to select specific tenants to create a service principal (SPN) for and add a secret to a key vault.
Tenant-Specific Actions:
For each selected tenant:
It connects to the Microsoft Graph API using Connect-MgGraph.
Retrieves user information using Get-MgUser.
Sets the Azure context to the selected subscription and tenant using set-azcontext.
Creates a new Azure AD service principal using New-AzADServicePrincipal.

 
 #>

 
 
 Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
   
#################  Connecto toe azure context based on login credentials 
#######  if connect-axaacount -Identity is used, the managed identity will be used for context in the execution 
#######  for Azure government tenant use  , run connect-azconnect -Environment AzureUSGovernment
cls

  
$rootcontext =  connect-azaccount 
 set-azcontext -Tenant  $($rootcontext.Context.Tenant.TenantId) -Subscription $($rootcontext.Context.Subscription.Name)
 


$token = Get-AzAccessToken -ResourceUrl "https://management.azure.com/"
Write-Output "Access Token: $($token.Token)"



$aadaccesstoken = Get-AzAccessToken -TenantId $($tenantid)
 

 $keyvault  = 'wolffadminkvwolff'


#$tenants = get-aztenant | select  -property *

 $tenantdetails = get-aztenant | select -property * -Verbose

 $tenantselected = $tenantdetails | ogv -Title "select tenants to create SPN for and add secret to keyvault:" -passthru | select *

  foreach ($tenant in   $tenantselected)
 {

    try {
    
        $($tenantype.tenanttype)

     #       if($($tenantype.tenanttype) -eq 'AAD')
       #     {
        
                $spnrec = ''

                 Write-host " $($tenant.tenantid) - $($tenant.name) " -ForegroundColor cyan

                        Connect-MgGraph  -Scopes "User.ReadWrite.All"  -TenantId $($tenant.TenantId) -NoWelcome

                       $tenantusers = Get-MgUser -All  -Property *


               # $tenantusers

                 
                 $runcontext = connect-azaccount -tenant $($tenant.tenantid) 

                 $runcontext
                 


              #  $subscription =     get-azsubscription | ogv -Title "select a subscription: " -PassThru | select name, id, tenant -first 1


               # $subscription 


                #set-azcontext -Subscription $($subscription.name) -Tenant $($tenant.tenantid) 


                 Write-host " Tenant/sub : $($subscription.name)  - $($tenant.tenantid)  " -foregroundcolor Green

                 $sp = New-AzADServicePrincipal -DisplayName "wolfftestspn"

                $sp | fl *


                ($sp.PasswordCredentials).GetEnumerator() | Foreach-object {


                    $spnobj = new-object PSObject 

                    $spnobj | Add-Member -MemberType NoteProperty -name Tenantid -Value $($tenant.tenantid)
                    $spnobj | Add-Member -MemberType NoteProperty -name Applicationid -Value $($sp.AppId)
                    $spnobj | Add-Member -MemberType NoteProperty -name Displayname -value $($sp.DisplayName)
                    $spnobj | Add-Member -MemberType NoteProperty -name ClientID -Value $($sp.AppId)
                    $spnobj | Add-Member -MemberType NoteProperty -name Clientsecret -Value $($_.secrettext)
                    $spnobj | Add-Member -MemberType NoteProperty -name Keyid -Value $($_.keyId)
                    $spnobj | Add-Member -MemberType NoteProperty -name Enddate -Value $($_.enddatetime)
                    $spnobj | Add-Member -MemberType NoteProperty -name startdate -Value $($_.startdatetime)


                    [array]$spnrec += $spnobj
    
           #   } ## foreach-object end


        $spnrec 

                $context =   set-azcontext -Context $($rootcontext.Context) 
                

                Get-AzKeyVault -VaultName "$keyvault" -ResourceGroupName "Adminrg"  -SubscriptionId $($context.Subscription.Id)

                 $secureSecretValue = ConvertTo-SecureString -String "$($spnrec.Clientsecret)" -AsPlainText -Force


                Set-AzKeyVaultSecret -VaultName "$keyvault" -Name "$($spnrec.clientid)" -SecretValue  $secureSecretValue
            
                Get-AzKeyVaultsecret -VaultName "$keyvault" -Name "$($spnrec.clientid)"  -AsPlainText

                ####cleanup previous ones

                    
                Remove-AzKeyVaultKey -VaultName "$keyvault" -Name "$($spnrec.displayname)" -Force -InRemovedState -ErrorAction Ignore

                add-AzKeyVaultKey -VaultName "$keyvault" -Name "$($spnrec.displayname)" -Tag @{Purpose = "Spnautomation"; Clientid ="$($spnrec.clientid)" ; Enddatetime = "$($spnrec.Enddate)"; keyid = "$($spnrec.keyid)"} -Destination Software 

                Get-AzKeyVaultKey -VaultName "$keyvault" -Name "$($spnrec.displayname)"


                Get-AzKeyVaultKey -VaultName "$keyvault" -Name "$($spnrec.displayname)" 
            }
        }
        Catch
        {

            Write-Information "no more non-b2c tenants"
        }
  

}



 













































