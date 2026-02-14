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

    Scriptname: \get_user_registered_devices_full.ps1
    Description:  Script to connect to AzureAd and get a report of user registered devices 
                   
                  Script will generate report localcsv ouptu to c:\temp  and output a CSV to a storage account
          

    Purpose:  Audit user registered Devices
    requires : Privileged Authentication Administrator | Assignments
             :UserAuthenticationMethod.Read.All if using a service principal 
    you need the following Azure RBAC roles:

        Global Administrator
        Azure AD Administrator
        Application Administrator
        Directory Reader
        User Administrator
        Privileged Role Administrator
        These roles will provide the necessary permissions to manage and execute the required tasks

#>
## uncomment during first run
#install-module Azuread -allowclobber
#install-module Microsoft.Graph -allowclobber

  'microsoft.graph','ADAL.PS','Azuread','az', 'Microsoft.Graph.Identity.DirectoryManagement'  | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         update-module $_ -force  -ErrorAction Ignore |out-null
         import-module -name $_ -force -ErrorAction Ignore |out-null
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
        install-module -name $_ -allowclobber -Force -ErrorAction Ignore|out-null 
        import-module -name $_ -force  -ErrorAction Ignore |out-null
    }
   #  Get-InstalledModule
}
  
 #Import-Module Azuread 
 #import-module Microsoft.Graph.Identity.DirectoryManagement

 $MaximumFunctionCount = 16384
$MaximumVariableCount = 16384
 #clear-azconfig

   
  $context = connect-azaccount -identity 
 Connect-MgGraph -Identity -NoWelcome
connect-azuread -TenantId $($context.Context.Tenant.TenantId)

$aadaccesstoken = Get-AzAccessToken 

try{Get-AzureADTenantDetail}catch{connect-azuread   }

set-azcontext -Subscription wolffentpsub

$deviceregistrationinfo = ''

# Get all users in the tenant
 
            set-azcontext -Tenant (get-aztenant -TenantId $($context.Context.Tenant.Id))


              Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
 

            $accessToken = Get-AzAccessToken -TenantId $($context.Tenant.Id) 
             
 #####################################
 
 
 
 $alldevices = Get-MgDevice -all | Select `
    deviceid,displayname, operatingsystem, OperatingSystemVersion, accountenabled, profiletype, trusttype, `
    onPremisesSyncEnabled, @{N="enrollmentType";Expression={$_.AdditionalProperties.enrollmentType}}, `
    @{N="enrollmentProfileName";Expression={$_.AdditionalProperties.enrollmentProfileName}}, `
    @{N="createdDateTime";Expression={(get-date $_.AdditionalProperties.createdDateTime).tostring('yyyy-MM-dd')}}, `
    @{N="ApproximateLastSignInDateTime";Expression={(get-date $_.ApproximateLastSignInDateTime).tostring('yyyy-MM-dd')}}  

 
 ####################################
#$deviceinfo  =  Get-AzureADUserRegisteredDevice -ObjectId  'e594a530-1ec9-4192-a8d4-a9111f8cffa7'  | select -Property *
     
    # Get all users
    $users = Get-AzureADUser  -All $true

    # Loop through each user
    foreach ($user in $users) {

        # Get the user's registered devices
        $devices = Get-AzureADUserRegisteredDevice -ObjectId $user.ObjectId

         $fg = 'green'
        # Output the user's display name and the number of registered devices
        if($($devices.Count) -gt 0)
        {
            $fg = 'red'
       # Write-host "$($user.DisplayName) has $($devices.Count) registered devices" -ForegroundColor $fg
           # $devices | fl *
        }
                Write-host "$($user.DisplayName) has $($devices.Count) registered devices" -ForegroundColor $fg
           $registrationMethod = $device.DeviceTrustType
       
          
     if($devices)
        {
         foreach($device in $devices)
           {
##userinfo
            $devapproxlastsignin = ($alldevices) | where Deviceid -eq $($device.DeviceId) | select ApproximateLastSignInDateTime , createdDateTime

            $deviceobj = new-object PSObject
            $deviceobj | add-member -membertype noteproperty -name Devicecount -value $($devices.Count)
            $deviceobj | add-member -membertype noteproperty -name AgeGroup -value $($user.AgeGroup)
            $deviceobj | add-member -membertype noteproperty -name AssignedLicenses -value $($user.AssignedLicenses)
            $deviceobj | add-member -membertype noteproperty -name AssignedPlans -value "$($user.AssignedPlans.Capacity)" 
            $deviceobj | add-member -membertype noteproperty -name City -value $($user.City)
            $deviceobj | add-member -membertype noteproperty -name CompanyName -value $($user.CompanyName)
            $deviceobj | add-member -membertype noteproperty -name ConsentProvidedForMinor -value $($user.ConsentProvidedForMinor)
            $deviceobj | add-member -membertype noteproperty -name Country -value $($user.Country)
            $deviceobj | add-member -membertype noteproperty -name CreationType -value $($user.CreationType)
            $deviceobj | add-member -membertype noteproperty -name DeletionTimestamp -value $($user.DeletionTimestamp)
            $deviceobj | add-member -membertype noteproperty -name Department -value $($user.Department)
            $deviceobj | add-member -membertype noteproperty -name UserDirSyncEnabled -value ($($user.DirSyncEnabled)| ConvertTo-Json -Depth 100)
            $deviceobj | add-member -membertype noteproperty -name DisplayName -value $($user.DisplayName)
 
            $deviceobj | add-member -membertype noteproperty -name FacsimileTelephoneNumber -value $($user.FacsimileTelephoneNumber)
            $deviceobj | add-member -membertype noteproperty -name GivenName -value $($user.GivenName)
            $deviceobj | add-member -membertype noteproperty -name ImmutableId -value $($user.ImmutableId)
            $deviceobj | add-member -membertype noteproperty -name IsCompromised -value $($user.IsCompromised)
            $deviceobj | add-member -membertype noteproperty -name JobTitle -value $($user.JobTitle)
            $deviceobj | add-member -membertype noteproperty -name LastDirSyncTime -value $($user.LastDirSyncTime)
            $deviceobj | add-member -membertype noteproperty -name LegalAgeGroupClassification -value $($user.LegalAgeGroupClassification)
            $deviceobj | add-member -membertype noteproperty -name Mail -value $($user.Mail)
            $deviceobj | add-member -membertype noteproperty -name MailNickName -value $($user.MailNickName)
            $deviceobj | add-member -membertype noteproperty -name Mobile -value $($user.Mobile)
            $deviceobj | add-member -membertype noteproperty -name ObjectId -value $($user.ObjectId)
            $deviceobj | add-member -membertype noteproperty -name ObjectType -value $($user.ObjectType)
            $deviceobj | add-member -membertype noteproperty -name OnPremisesSecurityIdentifier -value $($user.OnPremisesSecurityIdentifier)
            $deviceobj | add-member -membertype noteproperty -name OtherMails -value ($($user.OtherMails))
            $deviceobj | add-member -membertype noteproperty -name PasswordPolicies -value $($user.PasswordPolicies)
            $deviceobj | add-member -membertype noteproperty -name PasswordProfile -value $($user.PasswordProfile)
            $deviceobj | add-member -membertype noteproperty -name PhysicalDeliveryOfficeName -value $($user.PhysicalDeliveryOfficeName)
            $deviceobj | add-member -membertype noteproperty -name PostalCode -value $($user.PostalCode)
            $deviceobj | add-member -membertype noteproperty -name PreferredLanguage -value $($user.PreferredLanguage)
            $deviceobj | add-member -membertype noteproperty -name ProvisionedPlans -value $($user.ProvisionedPlans.Capacity)
            $deviceobj | add-member -membertype noteproperty -name ProvisioningErrors -value $($user.ProvisioningErrors)
            $deviceobj | add-member -membertype noteproperty -name ProxyAddresses -value $($user.ProxyAddresses)
            $deviceobj | add-member -membertype noteproperty -name RefreshTokensValidFromDateTime -value $($user.RefreshTokensValidFromDateTime)
            $deviceobj | add-member -membertype noteproperty -name ShowInAddressList -value $($user.ShowInAddressList)
            $deviceobj | add-member -membertype noteproperty -name SignInNames -value $($user.SignInNames)
            $deviceobj | add-member -membertype noteproperty -name SipProxyAddress -value $($user.SipProxyAddress)
            $deviceobj | add-member -membertype noteproperty -name State -value $($user.State)
            $deviceobj | add-member -membertype noteproperty -name StreetAddress -value $($user.StreetAddress)
            $deviceobj | add-member -membertype noteproperty -name Surname -value $($user.Surname)
            $deviceobj | add-member -membertype noteproperty -name TelephoneNumber -value $($user.TelephoneNumber)
            $deviceobj | add-member -membertype noteproperty -name UsageLocation -value $($user.UsageLocation)
            $deviceobj | add-member -membertype noteproperty -name UserPrincipalName -value $($user.UserPrincipalName)
            $deviceobj | add-member -membertype noteproperty -name UserState -value $($user.UserState)
            $deviceobj | add-member -membertype noteproperty -name UserStateChangedOn -value $($user.UserStateChangedOn)
            $deviceobj | add-member -membertype noteproperty -name UserType -value $($user.UserType)
       




           # Output the device's display name and registration method      
        ### Deviceinfo             


                    $deviceobj | add-member -membertype noteproperty -name DeviceAccountEnabled -value $($device.AccountEnabled)[0]
         
                    $deviceobj | add-member -membertype noteproperty -name ApproximateLastLogonTimeStamp -value "$($device.ApproximateLastLogonTimeStamp)"
                    $deviceobj | add-member -membertype noteproperty -name ComplianceExpiryTime -value $($device.ComplianceExpiryTime)
                    $deviceobj | add-member -membertype noteproperty -name DeviceDeletionTimestamp -value $($device.DeletionTimestamp)
                    $deviceobj | add-member -membertype noteproperty -name DeviceId -value $($device.DeviceId)
                    $deviceobj | add-member -membertype noteproperty -name DeviceMetadata -value $($device.DeviceMetadata)
                    $deviceobj | add-member -membertype noteproperty -name DeviceObjectVersion -value $($device.DeviceObjectVersion)
                    $deviceobj | add-member -membertype noteproperty -name DeviceOSType -value $($device.DeviceOSType)
                    $deviceobj | add-member -membertype noteproperty -name DeviceOSVersion -value $($device.DeviceOSVersion)
                    $deviceobj | add-member -membertype noteproperty -name DevicePhysicalIds -value "$($device.DevicePhysicalIds.Capacity)"
                    $deviceobj | add-member -membertype noteproperty -name DeviceTrustType -value $($device.DeviceTrustType)
                    $deviceobj | add-member -membertype noteproperty -name DirSyncEnabled -value $($device.DirSyncEnabled)
                    $deviceobj | add-member -membertype noteproperty -name DeviceDisplayName -value $($device.DisplayName)
                    $deviceobj | add-member -membertype noteproperty -name IsCompliant -value $($device.IsCompliant)
                    $deviceobj | add-member -membertype noteproperty -name IsManaged -value $($device.IsManaged)
                    $deviceobj | add-member -membertype noteproperty -name DeviceLastDirSyncTime -value $($device.LastDirSyncTime)
                    $deviceobj | add-member -membertype noteproperty -name DeviceObjectId -value ($($device.ObjectId))
                    $deviceobj | add-member -membertype noteproperty -name DeviceObjectType -value $($device.ObjectType)
                    $deviceobj | add-member -membertype noteproperty -name ProfileType -value $($device.ProfileType)
                    $deviceobj | add-member -membertype noteproperty -name SystemLabels -value $($device.SystemLabels)
                    $deviceobj | add-member -membertype noteproperty -name ApproximateLastSignInDateTime -value $($devapproxlastsignin.ApproximateLastSignInDateTime)
                    $deviceobj | add-member -membertype noteproperty -name createdDateTime -value $($devapproxlastsignin.createdDateTime)
                  
                      Write-Output "$($device.DisplayName) is registered using the $registrationMethod method"
                       [array]$deviceregistrationinfo += $deviceobj

                    }
                }
      else
        {

              ##userinfo
              $devapproxlastsignin = ($alldevices) | where Deviceid -eq $($device.DeviceId) | select ApproximateLastSignInDateTime , createdDateTime

                  $deviceobj = new-object PSObject
                $deviceobj | add-member -membertype noteproperty -name Devicecount -value $($devices.Count)
                $deviceobj | add-member -membertype noteproperty -name AgeGroup -value $($user.AgeGroup)
                $deviceobj | add-member -membertype noteproperty -name AssignedLicenses -value $($user.AssignedLicenses)
                $deviceobj | add-member -membertype noteproperty -name AssignedPlans -value "$($user.AssignedPlans.Capacity)" 
                $deviceobj | add-member -membertype noteproperty -name City -value $($user.City)
                $deviceobj | add-member -membertype noteproperty -name CompanyName -value $($user.CompanyName)
                $deviceobj | add-member -membertype noteproperty -name ConsentProvidedForMinor -value $($user.ConsentProvidedForMinor)
                $deviceobj | add-member -membertype noteproperty -name Country -value $($user.Country)
                $deviceobj | add-member -membertype noteproperty -name CreationType -value $($user.CreationType)
                $deviceobj | add-member -membertype noteproperty -name DeletionTimestamp -value $($user.DeletionTimestamp)
                $deviceobj | add-member -membertype noteproperty -name Department -value $($user.Department)
                $deviceobj | add-member -membertype noteproperty -name UserDirSyncEnabled -value ($($user.DirSyncEnabled)| ConvertTo-Json -Depth 100)
                $deviceobj | add-member -membertype noteproperty -name DisplayName -value $($user.DisplayName)
 
                $deviceobj | add-member -membertype noteproperty -name FacsimileTelephoneNumber -value $($user.FacsimileTelephoneNumber)
                $deviceobj | add-member -membertype noteproperty -name GivenName -value $($user.GivenName)
                $deviceobj | add-member -membertype noteproperty -name ImmutableId -value $($user.ImmutableId)
                $deviceobj | add-member -membertype noteproperty -name IsCompromised -value $($user.IsCompromised)
                $deviceobj | add-member -membertype noteproperty -name JobTitle -value $($user.JobTitle)
                $deviceobj | add-member -membertype noteproperty -name LastDirSyncTime -value $($user.LastDirSyncTime)
                $deviceobj | add-member -membertype noteproperty -name LegalAgeGroupClassification -value $($user.LegalAgeGroupClassification)
                $deviceobj | add-member -membertype noteproperty -name Mail -value $($user.Mail)
                $deviceobj | add-member -membertype noteproperty -name MailNickName -value $($user.MailNickName)
                $deviceobj | add-member -membertype noteproperty -name Mobile -value $($user.Mobile)
                $deviceobj | add-member -membertype noteproperty -name ObjectId -value $($user.ObjectId)
                $deviceobj | add-member -membertype noteproperty -name ObjectType -value $($user.ObjectType)
                $deviceobj | add-member -membertype noteproperty -name OnPremisesSecurityIdentifier -value $($user.OnPremisesSecurityIdentifier)
                $deviceobj | add-member -membertype noteproperty -name OtherMails -value ($($user.OtherMails))
                $deviceobj | add-member -membertype noteproperty -name PasswordPolicies -value $($user.PasswordPolicies)
                $deviceobj | add-member -membertype noteproperty -name PasswordProfile -value $($user.PasswordProfile)
                $deviceobj | add-member -membertype noteproperty -name PhysicalDeliveryOfficeName -value $($user.PhysicalDeliveryOfficeName)
                $deviceobj | add-member -membertype noteproperty -name PostalCode -value $($user.PostalCode)
                $deviceobj | add-member -membertype noteproperty -name PreferredLanguage -value $($user.PreferredLanguage)
                $deviceobj | add-member -membertype noteproperty -name ProvisionedPlans -value $($user.ProvisionedPlans.Capacity)
                $deviceobj | add-member -membertype noteproperty -name ProvisioningErrors -value $($user.ProvisioningErrors)
                $deviceobj | add-member -membertype noteproperty -name ProxyAddresses -value $($user.ProxyAddresses)
                $deviceobj | add-member -membertype noteproperty -name RefreshTokensValidFromDateTime -value $($user.RefreshTokensValidFromDateTime)
                $deviceobj | add-member -membertype noteproperty -name ShowInAddressList -value $($user.ShowInAddressList)
                $deviceobj | add-member -membertype noteproperty -name SignInNames -value $($user.SignInNames)
                $deviceobj | add-member -membertype noteproperty -name SipProxyAddress -value $($user.SipProxyAddress)
                $deviceobj | add-member -membertype noteproperty -name State -value $($user.State)
                $deviceobj | add-member -membertype noteproperty -name StreetAddress -value $($user.StreetAddress)
                $deviceobj | add-member -membertype noteproperty -name Surname -value $($user.Surname)
                $deviceobj | add-member -membertype noteproperty -name TelephoneNumber -value $($user.TelephoneNumber)
                $deviceobj | add-member -membertype noteproperty -name UsageLocation -value $($user.UsageLocation)
                $deviceobj | add-member -membertype noteproperty -name UserPrincipalName -value $($user.UserPrincipalName)
                $deviceobj | add-member -membertype noteproperty -name UserState -value $($user.UserState)
                $deviceobj | add-member -membertype noteproperty -name UserStateChangedOn -value $($user.UserStateChangedOn)
                $deviceobj | add-member -membertype noteproperty -name UserType -value $($user.UserType)
              #deviceinfo                                           
                    $deviceobj | add-member -membertype noteproperty -name DeviceAccountEnabled -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name Registrationmethod -value  "NA"  
                    $deviceobj | add-member -membertype noteproperty -name ApproximateLastLogonTimeStamp -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name ComplianceExpiryTime -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceDeletionTimestamp -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceId -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceMetadata -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceObjectVersion -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceOSType -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceOSVersion -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DevicePhysicalIds -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceTrustType -value  "NA"
                    $deviceobj | add-member -membertype noteproperty -name DirSyncEnabled -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceDisplayName -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name IsCompliant -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name IsManaged -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceLastDirSyncTime -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceObjectId -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name DeviceObjectType -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name ProfileType -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name SystemLabels -value "NA"
                    $deviceobj | add-member -membertype noteproperty -name ApproximateLastSignInDateTime -value $($devapproxlastsignin.ApproximateLastSignInDateTime)
                    $deviceobj | add-member -membertype noteproperty -name createdDateTime -value $($devapproxlastsignin.createdDateTime)
                  
                   
                  
                    [array]$deviceregistrationinfo += $deviceobj
         }
          
}

$deviceregistrationinfo


$userinforeport =   $deviceregistrationinfo | SELECT Devicecount,  DeviceAccountEnabled,`
ApproximateLastLogonTimeStamp,`
ComplianceExpiryTime,`
DeviceDeletionTimestamp,`
DeviceId,`
DeviceMetadata,`
DeviceObjectVersion,`
DeviceOSType,`
DeviceOSVersion,`
DevicePhysicalIds,`
DeviceTrustType,`
UserDirSyncEnabled,`
DeviceDisplayName,`
IsCompliant,`
IsManaged,`
DeviceLastDirSyncTime,`
DeviceObjectId,`
DeviceObjectType,`
ProfileType,`
SystemLabels,`
AgeGroup,`
AssignedLicenses,`
AssignedPlans,`
City,`
CompanyName,`
ConsentProvidedForMinor,`
Country,`
CreationType,`
DeletionTimestamp,`
Department,`
DirSyncEnabled,`
DisplayName,`
ExtensionProperty,`
FacsimileTelephoneNumber,`
GivenName,`
ImmutableId,`
IsCompromised,`
JobTitle,`
LastDirSyncTime,`
LegalAgeGroupClassification,`
Mail,`
MailNickName,`
Mobile,`
ObjectId,`
ObjectType,`
OnPremisesSecurityIdentifier,`
OtherMails,`
PasswordPolicies,`
PasswordProfile,`
PhysicalDeliveryOfficeName,`
PostalCode,`
PreferredLanguage,`
ProvisionedPlans,`
ProvisioningErrors,`
ProxyAddresses,`
RefreshTokensValidFromDateTime,`
ShowInAddressList,`
SignInNames,`
SipProxyAddress,`
State,`
StreetAddress,`
Surname,`
TelephoneNumber,`
UsageLocation,`
UserPrincipalName,`
UserState,`
UserStateChangedOn,`
UserType ,`
ApproximateLastSignInDateTime ,createdDateTime | export-csv c:\temp\userdeviceinfo_mapped.csv -NoTypeInformation


 
 
$resultsfilename = 'userdeviceinfomapped.csv'

  $deviceregistrationinfo | SELECT Devicecount,  DeviceAccountEnabled,`
ApproximateLastLogonTimeStamp,`
ComplianceExpiryTime,`
DeviceDeletionTimestamp,`
DeviceId,`
DeviceMetadata,`
DeviceObjectVersion,`
DeviceOSType,`
DeviceOSVersion,`
DevicePhysicalIds,`
DeviceTrustType,`
UserDirSyncEnabled,`
DeviceDisplayName,`
IsCompliant,`
IsManaged,`
DeviceLastDirSyncTime,`
DeviceObjectId,`
DeviceObjectType,`
ProfileType,`
SystemLabels,`
AgeGroup,`
AssignedLicenses,`
AssignedPlans,`
City,`
CompanyName,`
ConsentProvidedForMinor,`
Country,`
CreationType,`
DeletionTimestamp,`
Department,`
DirSyncEnabled,`
DisplayName,`
ExtensionProperty,`
FacsimileTelephoneNumber,`
GivenName,`
ImmutableId,`
IsCompromised,`
JobTitle,`
LastDirSyncTime,`
LegalAgeGroupClassification,`
Mail,`
MailNickName,`
Mobile,`
ObjectId,`
ObjectType,`
OnPremisesSecurityIdentifier,`
OtherMails,`
PasswordPolicies,`
PasswordProfile,`
PhysicalDeliveryOfficeName,`
PostalCode,`
PreferredLanguage,`
ProvisionedPlans,`
ProvisioningErrors,`
ProxyAddresses,`
RefreshTokensValidFromDateTime,`
ShowInAddressList,`
SignInNames,`
SipProxyAddress,`
State,`
StreetAddress,`
Surname,`
TelephoneNumber,`
UsageLocation,`
UserPrincipalName,`
UserState,`
UserStateChangedOn,`
UserType ,`
ApproximateLastSignInDateTime ,createdDateTime |  export-csv  $resultsfilename  -notypeinformation




##### storage subinfo

connect-azaccount -id # if the storage account is in another tenant or under a different login - this becomes interactive
 

 







############# Replace Region for storage account , subscription where the storage account resides, resourcegroup, and storage account names below

$Region =  "West US"

 $subscriptionselected = 'wolffentpSub'



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'
$storagecontainer = 'userdeviceinfomapped'


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)


## un block storage 
# Enable Allow Storage Account Key Access
$scope = "/subscriptions/$($subscriptioninfo.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

$servicePrincipal = Get-AzADServicePrincipal -DisplayName "$($azcontext.Account)"

# Display the service principal's Object ID
$servicePrincipal.Id

# to enable only current running client ip 

# Get current public IP
$currentIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip

# Add the current IP to the storage account's network rules
Add-AzStorageAccountNetworkRule `
  -ResourceGroupName $resourcegroupname `
  -Name $storageaccountname `
  -IPAddressOrRange "$currentIP"


 

# Optional: Confirm the rule was added
Get-AzStorageAccountNetworkRuleSet `
  -ResourceGroupName $resourcegroupname `
  -Name $storageaccountname

######################################
  


<# Enable Allow Storage Account Key Access and Blob Public Access
Set-AzStorageAccount `
  -ResourceGroupName  $resourcegroupname `
  -Name $storageaccountname `
  -AllowSharedKeyAccess $true `
  -AllowBlobPublicAccess $true `
  -PublicNetworkAccess Enabled `
  -Force

# Set default network rule to allow
Update-AzStorageAccountNetworkRuleSet `
  -ResourceGroupName $resourcegroupname `
  -Name $storageaccountname `
  -DefaultAction Allow
  #>

# Confirm settings
(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname).PublicNetworkAccess


 $destContext = New-AzStorageContext -StorageAccountName "$storageaccountname" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$resourcegroupname" -Name $storageaccountname).Value | select -first 1)

 
 ####### 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose

         Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowBlobPublicAccess $true -AllowSharedKeyAccess $true  -force

     
        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
                                        -StorageAccountKey $StorageKey


             #Upload  .csv to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext
                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -Force













































