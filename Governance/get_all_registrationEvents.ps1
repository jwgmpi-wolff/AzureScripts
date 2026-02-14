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

    Scriptname: get_all_registrationEvents.ps1
    Description:  Script to connect to AzureAd and get a report of Device registration events 
                   
                  Script will generate report localcsv output to c:\temp  and output a CSV to a storage account
          

    Purpose:  Audit user registered Devices
    requires : Privileged Authentication Administrator | Assignments
             :UserAuthenticationMethod.Read.All if using a service principal 
   

#>







import-module azureAdpreview -force

$context = connect-azaccount -identity 
$aadaccesstoken = Get-AzAccessToken 

try{Get-AzureADTenantDetail}catch{connect-azuread  -AadAccessToken $aadaccesstoken }

 
 
#https://techcommunity.microsoft.com/t5/azure-active-directory-identity/protecting-microsoft-365-from-on-premises-attacks/ba-p/1751754
#https://docs.microsoft.com/en-us/azure/active-directory/reports-monitoring/reference-audit-activities


 $registrations =    Get-AzureADAuditDirectoryLogs -All  $true | where-object {$_.ActivityDisplayName -like '*regist*'}

 $registrationtable = ''
 

foreach($registationitem in $registrations)
{
     $initiatedby = $registrations.initiatedby.app | select -unique appid, Displayname, ServicePrincipalId, ServicePrincipalName
     $tgtmodifiedprops = $registrations.TargetResources.ModifiedProperties| select -unique DisplayName , OldValue, NewValue
 
 

             foreach($initiatedby in ($registrations.initiatedby.app))
            {

             foreach($tgtmodifiedprop in $tgtmodifiedprops)
              {

                    $deviceregobj = new-object PSObject 


                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  id    -value $($registationitem.id)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  Category    -value $($registationitem.Category)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  Result    -value $($registationitem.Result)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  ResultReason    -value $($registationitem.ResultReason)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  ActivityDisplayName    -value $($registationitem.ActivityDisplayName)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  ActivityDateTime    -value $($registationitem.ActivityDateTime)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  LoggedByService    -value $($registationitem.LoggedByService)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name  OperationType    -value $($registationitem.OperationType)
 
           


                    $deviceregobj | Add-Member -MemberType NoteProperty -Name initiatedbyAppid     -value $($initiatedby.AppId)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name initiatedbyDisplayname     -value $($initiatedby.DisplayName)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name initiatedbyServicePrincipalId     -value $($initiatedby.ServicePrincipalId)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name initiatedbyServicePrincipalName     -value "($($initiatedby.ServicePrincipalName))"
 
              

                    $deviceregobj | Add-Member -MemberType NoteProperty -Name Displayname  -value $($tgtmodifiedprop.displayname)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name OldValue     -value $($tgtmodifiedprop.OldValue)
                    $deviceregobj | Add-Member -MemberType NoteProperty -Name NewValue     -value $($tgtmodifiedprop.NewValue)
            


                }

            }
         
     
    $($registrations.AdditionalDetails | Select -unique).GetEnumerator() | foreach-object {

            $deviceregobj | Add-Member -MemberType NoteProperty -Name $($_.key)  -value $($_.value)
        }

    [array]$registrationtable +=  $deviceregobj
}

 

$registrationtable  



<#
Id                   
Category             
 
Result               
ResultReason         
ActivityDisplayName  
ActivityDateTime     
LoggedByService      
OperationType        
InitiatedBy        
 $registrations.initiatedby.app | select -unique appid, Displayname, ServicePrincipalId, ServicePrincipalName
# AppId DisplayName ,ServicePrincipalId, ServicePrincipalN
                                                                         
                                            
                 
TargetResources     
  $registrations.TargetResources.ModifiedProperties| select -unique DisplayName , OldValue, NewValue
  #  DisplayName,  OldValue, NewValue         
                      

AdditionalDetails    
$registrations.AdditionalDetails  | select -unique
 

Key               Value                                                                 
---               -----                                                                 
AdditionalInfo    Successfully joined device using account type: User with identifier...
Device Profile    RegisteredDevice                                                      
Device Trust Type Azure AD register                                                     
Device OS         Android                                                               
Device Id         cfde13c2-6fcf-48ff-b479-5b491c66c1b6                                  
User-Agent        Microsoft.OData.Client/7.12.5 

#>



$registrationtable | Select id,`
Category,`
Result,`
ResultReason,`
ActivityDisplayName,`
ActivityDateTime,`
LoggedByService,`
OperationType,`
initiatedbyAppid,`
initiatedbyDisplayname,`
initiatedbyServicePrincipalId,`
initiatedbyServicePrincipalName,`
Displayname,`
OldValue,`
NewValue,`
AdditionalInfo,`
"Device Profile",`
"Device Trust Type",`
"Device OS",`
"Device Id",`
User-Agent| where id -ne $null |export-csv c:\temp\registrationevents.csv -NoTypeInformation

$resultsfilename = 'registrationevents.csv' 




$registrationtable | Select id,`
Category,`
Result,`
ResultReason,`
ActivityDisplayName,`
ActivityDateTime,`
LoggedByService,`
OperationType,`
initiatedbyAppid,`
initiatedbyDisplayname,`
initiatedbyServicePrincipalId,`
initiatedbyServicePrincipalName,`
Displayname,`
OldValue,`
NewValue,`
AdditionalInfo,`
"Device Profile",`
"Device Trust Type",`
"Device OS",`
"Device Id",`
User-Agent| where id -ne $null |export-csv  $resultsfilename   -NoTypeInformation

 ############# Replace Region for storage account , subscription where the storage account resides, resourcegroup, and storage account names below

$Region =  "West US"

 $subscriptionselected = 'wolffentpSub'



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'
$storagecontainer = 'registrationevents'


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($context.Context.Tenant.Id)

 

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






