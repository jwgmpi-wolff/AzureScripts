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

    Description: This script is designed to connect to Azure and Microsoft Graph, retrieve information about 
    protected items in Azure Recovery Services, and generate an HTML report. Here's a breakdown of its functions:

Connect to Azure and Microsoft Graph:

Connect-AzAccount -Identity: Authenticates to Azure using managed identity.
set-azcontext -Subscription wolffentpsub: Sets the Azure context to a specific subscription.
Connect-MgGraph: Connects to Microsoft Graph.
Retrieve Subscription Context:

$account = connect-azaccount -identity: Re-authenticates to Azure.
$context = get-azsubscription -SubscriptionName $($account.Context.Subscription.Name): Retrieves the subscription context.
Query Azure Resources:

$queryselected = {recoveryservicesresources | where properties contains "protection"}: Defines a query to select
 resources with properties containing "protection".
$queryresults = Search-AzGraph -Query "$($queryselected.query)": Executes the query to search Azure resources.
$detailcontents = Search-AzGraph -Query "RecoveryServicesResources | where type in~ ('Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems')
 | extend properties = parse_json(properties)": Retrieves detailed information about protected items.
Process and Store Results:

Iterates through the retrieved properties and creates a new PowerShell object for each item.
Adds various properties to the object, such as backupManagementType, dataSourceId, extendedInfo, and many others.
Stores the objects in an array $protectedlist.
Generate HTML Report:

Defines CSS styles for the HTML report.
Checks if the C:\Temp directory exists and creates it if not.
Converts the $protectedlist array to HTML format with the defined CSS styles.
Saves the HTML report to c:\temp\protecteditems.html.
Opens the HTML report using invoke-item.

#> 


 
Connect-AzAccount -Identity
 
set-azcontext -Subscription wolffentpsub 



   $account = connect-azaccount -identity
   Connect-MgGraph 


   $context = get-azsubscription -SubscriptionName $($account.Context.Subscription.Name)
    
 

   $protectedlist = '' 
    
 
$detailcontents = Search-AzGraph -Query "
RecoveryServicesResources 
| where type in~ ('Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems') 
| extend properties = parse_json(properties)"
#//| project name, type, properties.snapshots"


$detailcontents.properties

foreach($detailcontent in $detailcontents.properties)
{

    # Create a new PowerShell object
    $recoveryobj = New-Object PSObject

 $recoveryobj | Add-Member -MemberType NoteProperty -Name backupManagementType -value $($detailcontent.backupManagementType)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name dataSourceId -value $($detailcontent.dataSourceId)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name extendedInfo -value $($detailcontent.extendedInfo)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name sourceSideScanInfo -value $($detailcontent.sourceSideScanInfo)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name isAzureManagedLinkedResource -value $($detailcontent.isAzureManagedLinkedResource)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name deferredDeleteTimeRemaining -value $($detailcontent.deferredDeleteTimeRemaining)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name configuredRPGenerationFrequencyInSecondaryRegion -value $($detailcontent.configuredRPGenerationFrequencyInSecondaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name containerName -value $($detailcontent.containerName)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name configuredMaximumRetentionInSecondaryRegion -value $($detailcontent.configuredMaximumRetentionInSecondaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name resourceGuardOperationRequests -value $($detailcontent.resourceGuardOperationRequests)
 
$allowedOperationsEnumerator = @($($detailcontent.allowedOperations).GetEnumerator())
$recoveryobj | Add-Member -MemberType NoteProperty -Name "allowedOperations" -Value "$($allowedOperationsEnumerator)"

 #$recoveryobj | Add-Member -MemberType NoteProperty -Name allowedOperations -value @($($detailcontent.allowedOperations).GetEnumerator())
 $recoveryobj | Add-Member -MemberType NoteProperty -Name protectionStatus -value $($detailcontent.protectionStatus)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name oldestRecoveryPointInSecondaryRegion -value $($detailcontent.oldestRecoveryPointInSecondaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name rpoWarningThresholdInSecondaryRegion -value $($detailcontent.rpoWarningThresholdInSecondaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name latestRecoveryPointInSecondaryRegion -value $($detailcontent.latestRecoveryPointInSecondaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name rpoWarningThresholdInPrimaryRegion -value $($detailcontent.rpoWarningThresholdInPrimaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name protectionStateInSecondaryRegion -value $($detailcontent.protectionStateInSecondaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name isDeferredDeleteScheduleUpcoming -value $($detailcontent.isDeferredDeleteScheduleUpcoming)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name workloadType -value $($detailcontent.workloadType)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name configuredRPGenerationFrequency -value $($detailcontent.configuredRPGenerationFrequency)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name friendlyName -value $($detailcontent.friendlyName)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name policyId -value $($detailcontent.policyId)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name isScheduledForDeferredDelete -value $($detailcontent.isScheduledForDeferredDelete)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name configuredMaximumRetention -value $($detailcontent.configuredMaximumRetention)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name currentProtectionState -value $($detailcontent.currentProtectionState)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name softDeleteRetentionPeriod -value $($detailcontent.softDeleteRetentionPeriod)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name deferredDeleteTimeInUTC -value $($detailcontent.deferredDeleteTimeInUTC)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name protectedPrimaryRegion -value $($detailcontent.protectedPrimaryRegion)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name protectedItemType -value $($detailcontent.protectedItemType)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name lastRecoveryPoint -value $($detailcontent.lastRecoveryPoint)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name dataSourceSetInfo -value $($detailcontent.dataSourceSetInfo)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name protectionState -value $($detailcontent.protectionState)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name sourceResourceId -value $($detailcontent.sourceResourceId)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name dataSourceInfo -value $($detailcontent.dataSourceInfo)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name isArchiveEnabled -value $($detailcontent.isArchiveEnabled)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name lastBackupStatus -value $($detailcontent.lastBackupStatus)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name policyName -value $($detailcontent.policyName)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name isInlineInquiry -value $($detailcontent.isInlineInquiry)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name lastBackupTime -value $($detailcontent.lastBackupTime)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name backupSetName -value $($detailcontent.backupSetName)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name isDatasourceDeleted -value $($detailcontent.isDatasourceDeleted)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name isRehydrate -value $($detailcontent.isRehydrate)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name kpisHealths -value $($detailcontent.kpisHealths)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name vaultId -value $($detailcontent.vaultId)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name policyInfo -value $($detailcontent.policyInfo)
 $recoveryobj | Add-Member -MemberType NoteProperty -Name createMode -value $($detailcontent.createMode)


    # Output the object
    [array]$protectedlist +=$recoveryobj


}

 
$protectedlist| select backupManagementType,`
dataSourceId,`
extendedInfo,`
sourceSideScanInfo,`
isAzureManagedLinkedResource,`
deferredDeleteTimeRemaining,`
configuredRPGenerationFrequencyInSecondaryRegion,`
containerName,`
configuredMaximumRetentionInSecondaryRegion,`
resourceGuardOperationRequests,`
allowedOperations,`
protectionStatus,`
oldestRecoveryPointInSecondaryRegion,`
rpoWarningThresholdInSecondaryRegion,`
latestRecoveryPointInSecondaryRegion,`
rpoWarningThresholdInPrimaryRegion,`
protectionStateInSecondaryRegion,`
isDeferredDeleteScheduleUpcoming,`
workloadType,`
configuredRPGenerationFrequency,`
friendlyName,`
policyId,`
isScheduledForDeferredDelete,`
configuredMaximumRetention,`
currentProtectionState,`
softDeleteRetentionPeriod,`
deferredDeleteTimeInUTC,`
protectedPrimaryRegion,`
protectedItemType,`
lastRecoveryPoint,`
dataSourceSetInfo,`
protectionState,`
sourceResourceId,`
dataSourceInfo,`
isArchiveEnabled,`
lastBackupStatus,`
policyName,`
isInlineInquiry,`
lastBackupTime,`
backupSetName,`
isDatasourceDeleted,`
isRehydrate,`
kpisHealths,`
vaultId,`
policyInfo,`
createMode



$CSS = @"

<Title>Azure protecteditems : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure protecteditems:$(Get-Date -Format 'dd MMMM yyyy')  </H2>

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


if (-Not (Test-Path -Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory
}


($protectedlist| select backupManagementType,`
dataSourceId,`
extendedInfo,`
sourceSideScanInfo,`
isAzureManagedLinkedResource,`
deferredDeleteTimeRemaining,`
configuredRPGenerationFrequencyInSecondaryRegion,`
containerName,`
configuredMaximumRetentionInSecondaryRegion,`
resourceGuardOperationRequests,`
allowedOperations,`
protectionStatus,`
oldestRecoveryPointInSecondaryRegion,`
rpoWarningThresholdInSecondaryRegion,`
latestRecoveryPointInSecondaryRegion,`
rpoWarningThresholdInPrimaryRegion,`
protectionStateInSecondaryRegion,`
isDeferredDeleteScheduleUpcoming,`
workloadType,`
configuredRPGenerationFrequency,`
friendlyName,`
policyId,`
isScheduledForDeferredDelete,`
configuredMaximumRetention,`
currentProtectionState,`
softDeleteRetentionPeriod,`
deferredDeleteTimeInUTC,`
protectedPrimaryRegion,`
protectedItemType,`
lastRecoveryPoint,`
dataSourceSetInfo,`
protectionState,`
sourceResourceId,`
dataSourceInfo,`
isArchiveEnabled,`
lastBackupStatus,`
policyName,`
isInlineInquiry,`
lastBackupTime,`
backupSetName,`
isDatasourceDeleted,`
isRehydrate,`
kpisHealths,`
vaultId,`
policyInfo,`
createMode `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\protecteditems.html"


invoke-item "c:\temp\protecteditems.html"
