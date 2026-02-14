Install-Module -Name Microsoft.Graph -Force | out-null  #-Verbose 
#import-module Microsoft.Graph -force
#import-module Microsoft.Graph.Applications -force
#Import-Module Microsoft.Graph.Reports -force
get-module -ListAvailable | where name -like '*microsoft.graph.*' | import-module -force |out-null

$MaximumFunctionCount = 16384
$MaximumVariableCount = 16384
 
$Scopes = @(
    "AuditLog.Read.All",
    "Directory.Read.All"
)


connect-azaccount -Identity 

Connect-MgGraph -Scopes $Scopes

$signinreport = ''

$Logs = Get-MgAuditLogSignIn -all   
$Logs | Sort-Object -Property CreatedDateTime 
 




foreach($log in $logs)
{

    
    $signinobj = new-object PSobject 
    $appliedcondistionaaccess = $($log.AppliedConditionalAccessPolicies) 



    foreach($appliedca in $appliedcondistionaaccess)
    {

        $Appliedconditionalaccess_Displayname = $($appliedca.DisplayName)
        $Appliedconditionalaccess_EnforcedGrantControls = $($appliedca.EnforcedGrantControls)
        $Appliedconditionalaccess_EnforcedSessionControls = $($appliedca.EnforcedSessionControls)
        $Appliedconditionalaccess_Id = $($appliedca.ID) 
        $Appliedconditionalaccess_Result =  $($appliedca.Result)


        


    $signinloc = $($log.Location)
    # city, state CountryOrorigin

    $device_location_city  = $($signinloc.city)
    $device_location_state  = $($signinloc.state)
    $device_location_CountryOrorigin  = $($signinloc.CountryOrRegion)

    $deviceinfo = $($log.DeviceDetail)
    
    #Browser DeviceId   DisplayName   IsCompliant IsManaged OperatingSystem Tru

        $device_Browser   = $($deviceinfo.Browser)
        $device_DeviceId   = $($deviceinfo.DeviceId)
        $device_DisplayName   = $($deviceinfo.DisplayName)
        $device_IsCompliant   = $($deviceinfo.IsCompliant)
        $device_IsManaged   = $($deviceinfo.IsManaged)
        $device_OperatingSystem   = $($deviceinfo.OperatingSystem)
        $device_Tru   = $($deviceinfo.Tru)
      



   #$($log.Status)
   $statusDetails = $($log.Status.AdditionalDetails)
   $statusErrorcode = $($log.Status.ErrorCode)
   $statusFailurereason = $($log.Status.FailureReason)


         $signinobj = new-object PSobject

     $signinobj | add-member -membertype noteproperty -name  AppDisplayName -value $($log.AppDisplayName)
     $signinobj | add-member -membertype noteproperty -name  AppId -value $($log.AppId)
     $signinobj | add-member -membertype noteproperty -name  Appliedconditionalaccess_Displayname -value $Appliedconditionalaccess_Displayname
     $signinobj | add-member -membertype noteproperty -name  Appliedconditionalaccess_EnforcedGrantControls -value $Appliedconditionalaccess_EnforcedGrantControls
     $signinobj | add-member -membertype noteproperty -name  Appliedconditionalaccess_EnforcedSessionControls -value $Appliedconditionalaccess_EnforcedSessionControls
     $signinobj | add-member -membertype noteproperty -name  Appliedconditionalaccess_Id -value $Appliedconditionalaccess_Id
     $signinobj | add-member -membertype noteproperty -name  Appliedconditionalaccess_Result -value $Appliedconditionalaccess_Result

     $signinobj | add-member -membertype noteproperty -name  Devicemethod -Value  $device_Browser
     $signinobj | add-member -membertype noteproperty -name  DeviceId  -value $device_DeviceId
     $signinobj | add-member -membertype noteproperty -name  DeviceDisplayname -value $device_DisplayName
     $signinobj | add-member -membertype noteproperty -name  Device-iscompliant -Value $device_IsCompliant
     $signinobj | add-member -membertype noteproperty -name  Device_IsManaged  -value  $device_IsManaged
     $signinobj | add-member -membertype noteproperty -name  Device_OperatingSystem -value  $device_OperatingSyste
     $signinobj | add-member -membertype noteproperty -name  Device_Tru -value $device_Tru
     $signinobj | add-member -membertype noteproperty -name  Device_location_state -value $device_location_state
     $signinobj | add-member -membertype noteproperty -name  Device_location_CountryOrorigin -value $device_location_CountryOrorigin
     $signinobj | add-member -membertype noteproperty -name  Device_location_city -value  $device_location_city
     $signinobj | add-member -membertype noteproperty -name  StatusDetails -value $statusDetails
     $signinobj | add-member -membertype noteproperty -name  StatusErrorcode -value $statusErrorcode
     $signinobj | add-member -membertype noteproperty -name  StatusFailureReasn -value  $statusFailurereason


     $signinobj | add-member -membertype noteproperty -name  ClientAppUsed -value $($log.ClientAppUsed)
     $signinobj | add-member -membertype noteproperty -name  ConditionalAccessStatus -value $($log.ConditionalAccessStatus)
     $signinobj | add-member -membertype noteproperty -name  CorrelationId -value $($log.CorrelationId)
     $signinobj | add-member -membertype noteproperty -name  CreatedDateTime -value $($log.CreatedDateTime)

     $signinobj | add-member -membertype noteproperty -name  IPAddress -value $($log.IPAddress)
     $signinobj | add-member -membertype noteproperty -name  Id -value $($log.Id)
     $signinobj | add-member -membertype noteproperty -name  IsInteractive -value $($log.IsInteractive)
 
     $signinobj | add-member -membertype noteproperty -name  ResourceDisplayName -value $($log.ResourceDisplayName)
     $signinobj | add-member -membertype noteproperty -name  ResourceId -value $($log.ResourceId)
     $signinobj | add-member -membertype noteproperty -name  RiskDetail -value $($log.RiskDetail)
     $signinobj | add-member -membertype noteproperty -name  RiskEventTypes -value $($log.RiskEventTypes)
     $signinobj | add-member -membertype noteproperty -name  RiskEventTypesV2 -value $($log.RiskEventTypesV2)
     $signinobj | add-member -membertype noteproperty -name  RiskLevelAggregated -value $($log.RiskLevelAggregated)
     $signinobj | add-member -membertype noteproperty -name  RiskLevelDuringSignIn -value $($log.RiskLevelDuringSignIn)
     $signinobj | add-member -membertype noteproperty -name  RiskState -value $($log.RiskState)
     $signinobj | add-member -membertype noteproperty -name  Status -value $($log.Status)
     $signinobj | add-member -membertype noteproperty -name  UserDisplayName -value $($log.UserDisplayName)
     $signinobj | add-member -membertype noteproperty -name  UserId -value $($log.UserId)
     $signinobj | add-member -membertype noteproperty -name  UserPrincipalName -value $($log.UserPrincipalName)
 


     [array]$signinreport += $signinobj
      }
   }

    

    $CSS = @"
<Title>Signin Report:$(Get-Date -Format 'dd MMMM yyyy' )</Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	border-top: 1px solid #C1DAD7;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #6D929B;
}
</Style>
"@





$signinreport| select AppDisplayName,`
AppId,`
ClientAppUsed,`
Appliedconditionalaccess_Displayname,`
Appliedconditionalaccess_EnforcedGrantControls,`
Appliedconditionalaccess_EnforcedSessionControls,`
Appliedconditionalaccess_Id,`
Appliedconditionalaccess_Result,`
CorrelationId,`
CreatedDateTime,`
DeviceDetail,`
IPAddress,`
Id,`
IsInteractive,`
ResourceDisplayName,`
ResourceId,`
RiskDetail,`
RiskEventTypes,`
RiskEventTypesV2,`
RiskLevelAggregated,`
RiskLevelDuringSignIn,`
RiskState,`
statusDetails,`  
statusErrorcode ,` 
statusFailurereason,`
UserDisplayName,`
UserId,`
UserPrincipalName,`
Devicemethod,`
DeviceId,`
DeviceDisplayname,`
Device-iscompliant,`
Device_IsManaged,`
Device_OperatingSystem,`
Device_Tru,`
Device_location_state,`
device_location_CountryOrorigin,`
Device_location_city   | export-csv c:\temp\entrasignins.csv -NoTypeInformation


$resultsfilename = "usersignins.csv"



$signinreport| select AppDisplayName,`
AppId,`
ClientAppUsed,`
Appliedconditionalaccess_Displayname,`
Appliedconditionalaccess_EnforcedGrantControls,`
Appliedconditionalaccess_EnforcedSessionControls,`
Appliedconditionalaccess_Id,`
Appliedconditionalaccess_Result,`
CorrelationId,`
CreatedDateTime,`
IPAddress,`
Id,`
IsInteractive,`
ResourceDisplayName,`
ResourceId,`
RiskDetail,`
RiskEventTypes,`
RiskEventTypesV2,`
RiskLevelAggregated,`
RiskLevelDuringSignIn,`
RiskState,`
statusDetails,`  
statusErrorcode ,` 
statusFailurereason,`
UserDisplayName,`
UserId,`
UserPrincipalName,`
Devicemethod,`
DeviceId,`
DeviceDisplayname,`
Device-iscompliant,`
Device_IsManaged,`
Device_OperatingSystem,`
Device_Tru,`
Device_location_state,`
device_location_CountryOrorigin,`
Device_location_city  | export-csv $resultsfilename -NoTypeInformation



##############################################################################################


 ##### storage sub info and creation

#connect-azaccount ## only uncomment if using a storage account under another tenant or account for consilidation of reports 


 ########################################################################################################################
 ###

 #### Change subscription , Region, Resourcegroupname, Storageaccountname below 

$Region =  "West US"   ## pick storage account region 

 $subscriptionselected = 'wolffentpsub'   ### designated storage account subscription if different from current running subscription

 connect-azaccount -identity 

$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'    ## dedicate storage account
$storagecontainer = 'usersignins'   ### Container for export


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry contoso"; "purpose" = "Az Automation storage write" } -Verbose
 
     
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













 



























