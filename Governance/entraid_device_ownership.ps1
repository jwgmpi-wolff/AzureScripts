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

    Scriptname: \\entraid_device_ownership..ps1
    Description:  Script to connect to AzureAd and get a report of user registered devices 
                   
                  Script will generate report localcsv ouptu to c:\temp  and output a CSV to a storage account
          

    Purpose:  Audit user registered Devices ownership
    requires : Privileged Authentication Administrator | Assignments
             :UserAuthenticationMethod.Read.All if using a service principal 

   Modules :Microsoft.Graph.Identity.DirectoryManagement
            AZ

#>

 

Import-Module Microsoft.Graph.Identity.DirectoryManagement
connect-mggraph #-NoWelcome

$devices = Get-MgDevice -All  
$devices | fl *
$devownerlist = ''

foreach($device in $devices)
{

 
$devowner = Get-MgDeviceRegisteredOwner -All -DeviceId $($device.id)  -Property *
   $assigned = ''
  ($devowner.AdditionalProperties)

    if($devowner.AdditionalProperties)
    {
        foreach($deviceowner in ($devowner.AdditionalProperties)) 
        {
     

        $identities =  $($deviceowner.identities) 
                foreach($identity in $identities)
                {
                $assigned +=  $($identity.Values) 


                } 
                $assigned

    }

 
       

Write-Output " ___________________________" 


            $devobj = new-object psobject

             $devobj | Add-Member -MemberType NoteProperty -Name accountEnabled -value  $($deviceowner.accountEnabled) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name businessPhones -value  $($deviceowner.businessPhones) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name createdDateTime -value  $($deviceowner.createdDateTime) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name displayName -value  $($deviceowner.displayName) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name isLicenseReconciliationNeeded -value  $($deviceowner.isLicenseReconciliationNeeded) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name mail -value  $($deviceowner.mail) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name mailNickname -value  $($deviceowner.mailNickname) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name mobilePhone -value  $($deviceowner.mobilePhone) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name otherMails -value  $($deviceowner.otherMails) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name preferredLanguage -value  $($deviceowner.preferredLanguage) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name proxyAddresses -value  $($deviceowner.proxyAddresses) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name refreshTokensValidFromDateTime -value  $($deviceowner.refreshTokensValidFromDateTime) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name imAddresses -value  $($deviceowner.imAddresses) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name securityIdentifier -value  $($deviceowner.securityIdentifier) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name signInSessionsValidFromDateTime -value  $($deviceowner.signInSessionsValidFromDateTime) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name usageLocation -value  $($deviceowner.usageLocation) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name userPrincipalName -value  $($deviceowner.userPrincipalName) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name userType -value  $($deviceowner.userType) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name authorizationInfo -value  $($deviceowner.authorizationInfo) -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name identities -value  $assigned -erroraction ignore
             $devobj | Add-Member -MemberType NoteProperty -Name serviceProvisioningErrors -value  $($deviceowner.serviceProvisioningErrors) -erroraction ignore


            [array]$devownerlist += $devobj

    
            } 

     


}


$devownerlist



 ###GENERATE HTML Output for review        
 
    $CSS = @" 
  EntraId Device ownership Audit $date
<Title> Azure Role Audit $date Report: $date </Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	border-top: 1px solid #4B0082;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #4B0082;
}
</Style>
"@


 

 

 ((($devownerlist| SELECT  `
accountEnabled, `
businessPhones, `
createdDateTime, `
displayName, `
isLicenseReconciliationNeeded, `
mail, `
mailNickname, `
mobilePhone, `
otherMails, `
preferredLanguage, `
proxyAddresses, `
refreshTokensValidFromDateTime, `
imAddresses, `
securityIdentifier, `
signInSessionsValidFromDateTime, `
usageLocation, `
userPrincipalName, `
userType, `
identities | `
ConvertTo-Html -Head $CSS ).replace("root","<font color=red>root</font>")).replace("subscriptions","<font color=green>subscriptions</font>"))| out-file "C:\TEMP\EntraId_device_ownership_audit.html"
Invoke-Item    "C:\TEMP\EntraId_device_ownership_audit.html"                                                                                                     


######## Prep for export to storage account

$resultsfilename = 'entraiddeviceownership.csv'

$deviceownership =  $devownerlist| SELECT   `
accountEnabled, `
businessPhones, `
createdDateTime, `
displayName, `
isLicenseReconciliationNeeded, `
mail, `
mailNickname, `
mobilePhone, `
otherMails, `
preferredLanguage, `
proxyAddresses, `
refreshTokensValidFromDateTime, `
imAddresses, `
securityIdentifier, `
signInSessionsValidFromDateTime, `
usageLocation, `
userPrincipalName, `
userType, `
authorizationInfo, `
identities | export-csv  $resultsfilename  -notypeinformation




 ##### storage sub info and creation

#connect-azaccount ## only uncomment if using a storage account under another tenant or account for consilidation of reports 


 ########################################################################################################################
 ###

 #### Change subscription , Region, Resourcegroupname, Storageaccountname below 

$Region =  "West US"   ## pick storage account region 

 $subscriptionselected = 'wolffentpSub'   ### designated storage account subscription if different from current running subscription



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'    ## dedicate storage account
$storagecontainer = 'entradevices'   ### Container for export


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


 



