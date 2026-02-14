# Install MSAL.PS module
Import-Module Azuread

  $context = Connect-AzAccount -Identity
  

 Connect-AzureAD -Credential  ($context.Context.Account.Credential) 

# Register an Azure AD Application with Application Permissions for the UserAuthenticationMethod.Read.All scope
# Record the registered Application (client) ID and Directory (tenant) ID from the Overview page of the registered application for use in the script
# Generate a secret from the Certificates & secrets tab and record the secret also for use in the script

# Authenticate to Microsoft Graph using the Tenant ID and Application (client) ID and Client Secret of the AAD Registered Application that contains UserAuthenticationMethod.Read.All and User.Read.All Application permissions

#Connect-MsolService  -Credential ($context.Context.Account.Credential)


$deviceregistrationinfo = ''
# Get all users in the tenant


            set-azcontext -Tenant (get-aztenant -TenantId $($context.Context.Tenant.Id))


              Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
            try
            {
                $AzureLogin = Get-AzSubscription | Select-AzSubscription 
                $currentContext = Get-AzContext
                $accessToken = Get-AzAccessToken -TenantId $($context.Tenant.Id)
                if($accessToken.ExpiresOn -lt $(get-date))
                {
                    "Logging you out due to cached token is expired for REST AUTH.  Re-run script"
                    #$null = Disconnect-AzAccount        
                } 
             
                
 
            }
            catch
            {

                $AzureLogin = Get-AzSubscription  
                $currentContext = Get-AzContext
                $accessToken = Get-AzAccessToken -TenantId $($subscription.TenantId)
             
                   
 
            }

<# 
$users = Get-AzureADUser -All $true


Loop through each user and get their authentication methods and registration details
foreach ($user in $users) {
   <# $authMethods = Invoke-RestMethod -Headers @{Authorization = "Bearer $($accessToken)"} -Uri "https://graph.microsoft.com/users/$($user.ObjectId)/authentication/methods" -ErrorAction Ignore

    # Get the user's registered devices
    $devices = Get-AzureADUserRegisteredDevice -ObjectId $user.ObjectId

    # Output the user's display name and the number of registered devices
    Write-Output "$($user.DisplayName) has $($devices.Count) registered devices"

    $user | Add-Member -NotePropertyName AuthMethods -NotePropertyValue $authMethods
    $user | Add-Member -NotePropertyName AuthMethodsDetails -NotePropertyValue ($authMethods | ConvertTo-Json -Depth 100)
    $user | Add-Member -NotePropertyName AuthMethodsCount -NotePropertyValue ($authMethods | Measure-Object).Count
    Write-Output $user
} #>

    # Get all users
    $users = Get-AzureADUser  -All $true

    # Loop through each user
    foreach ($user in $users) {
        # Get the user's registered devices
        $devices = Get-AzureADUserRegisteredDevice -ObjectId $user.ObjectId
     
        # Output the user's display name and the number of registered devices
        Write-Output "$($user.DisplayName) has $($devices.Count) registered devices"
           # $devices | fl *
  
           $registrationMethod = $device.DeviceTrustType
       
          
     if($devices)
        {
         foreach($device in $devices)
           {
##userinfo
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

                      Write-Output "$($device.DisplayName) is registered using the $registrationMethod method"
                       [array]$deviceregistrationinfo += $deviceobj

                    }
                }
      else
        {

              ##userinfo
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
UserType  | export-csv c:\temp\userdeviceinfo.csv -NoTypeInformation



 $userdata 
 
$resultsfilename = 'userdeviceinfo.csv'

$userinforeport =   $deviceregistrationinfo | SELECT Devicecount,  DeviceAccountEnabled,`
AlternativeSecurityIds,`
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
UserType | export-csv  $resultsfilename  -notypeinformation


##### storage subinfo

#connect-azaccount 
 

$Region =  "West US"

 $subscriptionselected = 'wolffentpSub'



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'
$storagecontainer = 'userdeviceinfo'


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose
 
     
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






















