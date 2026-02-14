
 $MaximumVariableCount = 8192
 $MaximumFunctionCount = 8192
  
   
  
  
  'Microsoft.Graph.Applications', 'az'  | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         update-module $_ -force
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
        install-module -name $_ -allowclobber
        import-module -name $_ -force
    }
   #  Get-InstalledModule
}
  
 




$PSStyle.OutputRendering = 'PlainText'
$context = Connect-AzAccount -Tenantid 653eac6f-6d25-42f6-8cfa-a01bb45ab2dc  -force

$subscription = get-azsubscription -SubscriptionName wolffofficesub

$loginpermissions =  @(
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Group.ReadWrite.All","Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"
)

Connect-MgGraph -tenant $($subscription.TenantId) -Scopes $loginpermissions
 

 set-azcontext  -Tenantid $($context.Context.tenant.id)  -Subscription $($context.Context.Subscription.name)

 $spnrec = ''

    $resourceGroup = 'Adminrg'
    $vaultname = 'wolffofficekvkv2' 
    $spnname = 'wolffTeamsCallingBot'

 

                set-azcontext -Subscription $($context.Context.Subscription.name) -Tenant $($context.Context.tenant.id) 


                 Write-host " Tenant/sub : $($context.Context.Subscription.name) -Tenant $($context.Context.tenant.id)   " -foregroundcolor Green

                # Create the application
                $app = New-MgApplication -DisplayName "wolffTeamsCallingBot"

# Define SPN name
$spnname = "wolffTeamsCallingBot"

# Remove duplicate app registrations
        $existingApps = Get-MgApplication -Filter "DisplayName eq '$spnname'"

        if ($existingApps) {
            foreach ($app in $existingApps) {
                Write-Host "⚠️ Removing duplicate app registration: $($app.Id)" -ForegroundColor Yellow
                Remove-MgApplication -ApplicationId $app.Id -Confirm:$false
            }
            Write-Host "✅ Removed all duplicate app registrations." -ForegroundColor Green
        } else {
            Write-Host "ℹ️ No duplicate app registrations found." -ForegroundColor Cyan
        }

        # Remove existing service principal
        $existingSp = Get-MgServicePrincipal -Filter "DisplayName eq '$spnname'"

        if ($existingSp) {
            Write-Host "⚠️ Existing service principal found: $($existingSp.Id). Deleting..." -ForegroundColor Yellow
            Remove-MgServicePrincipal -ServicePrincipalId $existingSp.Id -Confirm:$false  
            Write-Host "✅ Deleted existing service principal." -ForegroundColor Green
        } else {
            Write-Host "ℹ️ No existing service principal found. Proceeding to create a new one." -ForegroundColor Cyan
        }

 
        # Create new service principal
        $sp = New-MgServicePrincipal -AppId $app.AppId

        # Output details
        $sp | Format-List *
        ###############################

                # Create the application
             $app = New-MgApplication -DisplayName $spnname

                # Create the service principal
                $mgsp = New-MgServicePrincipal -AppId $app.AppId

                # Output details
                $mgsp | Format-List *

$startDate = Get-Date
$endDate = $startDate.AddYears(5)

$clientSecret = @{
    DisplayName = "wolffteamscallsecret"
    StartDateTime = $startDate
    EndDateTime = $endDate
}

# Add the secret to the application
$secret = Add-MgApplicationPassword -ApplicationId $app.Id -PasswordCredential $clientSecret

# Convert to secure string if needed
$secureSecretValue = ConvertTo-SecureString -String $secret.SecretText -AsPlainText -Force

$sp = get-mgserviceprincipal -ServicePrincipalId $mgsp.Id


                ($sp) | Foreach-object {


                    $spnobj = new-object PSObject 

                    $spnobj | Add-Member -MemberType NoteProperty -name Tenantid -Value $($context.Context.tenant.id) 
                    $spnobj | Add-Member -MemberType NoteProperty -name Applicationid -Value $($sp.AppId)
                    $spnobj | Add-Member -MemberType NoteProperty -name Displayname -value $($sp.DisplayName)
                    $spnobj | Add-Member -MemberType NoteProperty -name ClientID -Value $($sp.AppId)
                    $spnobj | Add-Member -MemberType NoteProperty -name Appid -Value $($sp.AppId)
                    $spnobj | Add-Member -MemberType NoteProperty -name Clientsecret -Value $secret.SecretText
                    $spnobj | Add-Member -MemberType NoteProperty -name Keyid -Value $($_.keyId)
                    $spnobj | Add-Member -MemberType NoteProperty -name Enddate -Value $($endDate)
                    $spnobj | Add-Member -MemberType NoteProperty -name startdate -Value $($startDate)
                    $spnobj | Add-Member -MemberType NoteProperty -name objectid -Value $($sp.Id)


                    [array]$spnrec += $spnobj
    
              } ## foreach-object end


        $spnrec 
    # Get Microsoft Graph SPN
    
    $graphSp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

######add role 



# Permissions to assign
$permissions = @(
    "Calls.AccessMedia.All",
    "Calls.JoinGroupCall.All",
    "Calls.JoinGroupCallAsGuest.All",
    "OnlineMeetings.Read.All",
    "User.Read.All"
)

foreach ($perm in $permissions ) {
 
 $appRole = $graphSp.AppRoles | Where-Object {
        $_.Value -eq $perm -and $_.AllowedMemberTypes -contains "Application"
    }

    if ($appRole) {
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $spnrec[0].objectid `
            -PrincipalId $spnrec[0].objectid `
            -ResourceId $graphSp.Id `
            -AppRoleId $appRole.Id

        Write-Output "✅ Assigned $perm"
    } else {
        Write-Warning "⚠️ Permission $perm not found in Microsoft Graph SPN AppRoles"
    }



}

#########
 ## section to open access to keyvault if policy set for conditional aceess
 
                  
            Update-AzKeyVault -ResourceGroupName $resourceGroup `
                              -VaultName $vaultname `
                             -PublicNetworkAccess Enabled  

 
 

        $vault =   Get-AzKeyVault -VaultName "$vaultname" -ResourceGroupName "$resourceGroup"  -SubscriptionId $($subscription.Id)

        Update-AzKeyVaultNetworkRuleSet -VaultName "$vaultname" -Bypass AzureServices


        Set-AzKeyVaultAccessPolicy -VaultName "$vaultname" `
            -ObjectId "$($mysp.id)" `
            -PermissionsToSecrets set,get,list



######################################
## section to upload new SPn secret to the keyvault


                Get-AzKeyVault -VaultName "$vaultname" -ResourceGroupName "Adminrg"

                 $secureSecretValue = ConvertTo-SecureString -String "$($spnrec.Clientsecret)" -AsPlainText -Force


                Set-AzKeyVaultSecret -VaultName "$vaultname" -Name "$($spnrec.clientid)" `
                -SecretValue  $secureSecretValue -Tag @{Purpose = "Teamscallapi"; Clientid ="$($spnrec.clientid)" ; Enddatetime = "$($spnrec.Enddate)"; keyid = "$($spnrec.keyid)"}`
                -ContentType "$($spnrec.appid)"

                Get-AzKeyVaultsecret -VaultName "$vaultname" -Name "$($spnrec.clientid)"  -AsPlainText

                ####cleanup previous ones

                    
                Remove-AzKeyVaultKey -VaultName "$vaultname" -Name "$($spnrec.displayname)" -Force -InRemovedState -ErrorAction Ignore
                
                start-sleep -Seconds 30 

                add-AzKeyVaultKey -VaultName "$vaultname" -Name "$($spnrec.displayname)"`
                 -Tag @{Purpose = "Teamscallapi"; Clientid ="$($spnrec.clientid)" ; Enddatetime = "$($spnrec.Enddate)"; keyid = "$($spnrec.keyid)"} `
                 -Destination Software 

              
                Get-AzKeyVaultKey -VaultName "$vaultname" -Name "$($spnrec.displayname)"
 

            $serviceprincipal =  get-AzADServicePrincipal -DisplayName "$($spnrec.displayname)"

            $credsecret =       Get-AzKeyVaultsecret -VaultName "$vaultname" -name "$($serviceprincipal.appid)"  -AsPlainText

            $clientkeyinfo =  Get-AzKeyVaultKey -VaultName "$vaultname" -name "$($serviceprincipal.displayname)" 

            $secureSecretValue = ConvertTo-SecureString -String "$credsecret" -AsPlainText -Force

            $credentials =   New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $spnname , $secureSecretValue





 
















