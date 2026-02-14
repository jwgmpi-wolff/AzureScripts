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

Summary 
  
  This PowerShell script is designed to query Azure Recovery Services vaults for backup items,
   process the retrieved data, and generate a detailed HTML report. The script uses Azure 
   Resource Graph to execute the query and fetch the backup items, then processes each item to 
   extract relevant properties and finally exports the data to a CSV file and generates an HTML report.

Flow:
Module Import and Authentication:

Ensure the Az module is installed and imported.
Authenticate to Azure using Connect-AzAccount -Identity.
Define and Execute Query:

Define a Kusto query to list all backup items from Recovery Services vaults.
Execute the query using Search-AzGraph and store the response.
Process Backup Items:

Initialize an empty array to store processed backup items.
Iterate through each backup item in the response and create a new PowerShell object (PSObject) for each item.
Add relevant properties to the PSObject such as allowedOperations, backupManagementType, backupSetName, 
configuredMaximumRetention, etc.
Append each processed item to the array.
Export Data to CSV:

Select specific properties from the processed items and export them to a CSV file located at c:\temp\protecteditems.csv.
Generate HTML Report:

Define CSS styles for the HTML report.
Create HTML content including the report title, date, and table of backup items.
Save the HTML content to a file located at c:\temp\Azure_Recovery_services_items.html.
Open HTML Report:

Open the generated HTML report using Invoke-Item.


#> 
 

# Ensure you have the Az module installed and imported
#Install-Module -Name Az -AllowClobber -Force
Import-Module Az

# Authenticate to Azure
Connect-AzAccount -Identity

# Define the query to list all subscriptions with their management group hierarchy
$query = @"
recoveryservicesresources
| where type in~ ('Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems')
| extend vaultName = case(type =~ 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems', split(split(id, '/Microsoft.RecoveryServices/vaults/'),'/'), '--')
| extend dataSourceType = case(type =~ 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems', properties.backupManagementType, '--')
//| where dataSourceType == 'SCDPM'
| project vaultName, dataSourceType, properties
"@

# Execute the query using Azure Resource Graph
$response = Search-AzGraph -Query $query

# Display the results
#$response 

$protecteditems = ''
#$response.properties  


foreach($backupitem in ($response.properties) )
{
    $recitem = new-object PSobject 
     

$recitem | add-member -membertype noteproperty -name allowedOperations -value "($($backupitem.allowedOperations))"
$recitem | add-member -membertype noteproperty -name backupManagementType -value $($backupitem.backupManagementType)
$recitem | add-member -membertype noteproperty -name backupSetName -value $($backupitem.backupSetName)
$recitem | add-member -membertype noteproperty -name configuredMaximumRetention -value $($backupitem.configuredMaximumRetention)
$recitem | add-member -membertype noteproperty -name configuredMaximumRetentionInSecondaryRegion -value $($backupitem.configuredMaximumRetentionInSecondaryRegion)
$recitem | add-member -membertype noteproperty -name configuredRPGenerationFrequency -value $($backupitem.configuredRPGenerationFrequency)
$recitem | add-member -membertype noteproperty -name configuredRPGenerationFrequencyInSecondaryRegion -value $($backupitem.configuredRPGenerationFrequencyInSecondaryRegion)
$recitem | add-member -membertype noteproperty -name containerName -value $($backupitem.containerName)
$recitem | add-member -membertype noteproperty -name createMode -value $($backupitem.createMode)
$recitem | add-member -membertype noteproperty -name currentProtectionState -value $($backupitem.currentProtectionState)
$recitem | add-member -membertype noteproperty -name dataSourceId -value $($backupitem.dataSourceId)
$recitem | add-member -membertype noteproperty -name dataSourceInfo -value $($backupitem.dataSourceInfo)
$recitem | add-member -membertype noteproperty -name dataSourceInfo.datasourceType -value $($backupitem.dataSourceInfo.datasourceType)
$recitem | add-member -membertype noteproperty -name dataSourceInfo.resourceID -value $($backupitem.dataSourceInfo.resourceID)
$recitem | add-member -membertype noteproperty -name dataSourceInfo.resourceLocation -value $($backupitem.dataSourceInfo.resourceLocation)
$recitem | add-member -membertype noteproperty -name dataSourceSetInfo -value $($backupitem.dataSourceSetInfo)
$recitem | add-member -membertype noteproperty -name deferredDeleteTimeInUTC -value $($backupitem.deferredDeleteTimeInUTC)
$recitem | add-member -membertype noteproperty -name deferredDeleteTimeRemaining -value $($backupitem.deferredDeleteTimeRemaining)
$recitem | add-member -membertype noteproperty -name extendedInfo -value $($backupitem.extendedInfo)
$recitem | add-member -membertype noteproperty -name extendedInfo.oldest.RecoveryPoint -value $($backupitem.extendedInfo.oldest.RecoveryPoint)
$recitem | add-member -membertype noteproperty -name extendedInfo.oldest.recoveryPointCount -value $($backupitem.extendedInfo.oldest.recoveryPointCount)
$recitem | add-member -membertype noteproperty -name extendedInfo.oldestrecovery.oldestRecoveryPoint -value $($backupitem.extendedInfo.oldestrecovery.oldestRecoveryPoint)
$recitem | add-member -membertype noteproperty -name friendlyName -value $($backupitem.friendlyName)
$recitem | add-member -membertype noteproperty -name isArchiveEnabled -value $($backupitem.isArchiveEnabled)
$recitem | add-member -membertype noteproperty -name isAzureManagedLinkedResource -value $($backupitem.isAzureManagedLinkedResource)
$recitem | add-member -membertype noteproperty -name isDatasourceDeleted -value $($backupitem.isDatasourceDeleted)
$recitem | add-member -membertype noteproperty -name isDeferredDeleteScheduleUpcoming -value $($backupitem.isDeferredDeleteScheduleUpcoming)
$recitem | add-member -membertype noteproperty -name isInlineInquiry -value $($backupitem.isInlineInquiry)
$recitem | add-member -membertype noteproperty -name isRehydrate -value $($backupitem.isRehydrate)
$recitem | add-member -membertype noteproperty -name isScheduledForDeferredDelete -value $($backupitem.isScheduledForDeferredDelete)
$recitem | add-member -membertype noteproperty -name kpisHealths -value $($backupitem.kpisHealths)
$recitem | add-member -membertype noteproperty -name lastBackupStatus -value $($backupitem.lastBackupStatus)
$recitem | add-member -membertype noteproperty -name lastBackupTime -value $($backupitem.lastBackupTime)
$recitem | add-member -membertype noteproperty -name lastRecoveryPoint -value $($backupitem.lastRecoveryPoint)
$recitem | add-member -membertype noteproperty -name latestRecoveryPointInSecondaryRegion -value $($backupitem.latestRecoveryPointInSecondaryRegion)
$recitem | add-member -membertype noteproperty -name oldestRecoveryPointInSecondaryRegion -value $($backupitem.oldestRecoveryPointInSecondaryRegion)
$recitem | add-member -membertype noteproperty -name policyId -value $($backupitem.policyId)
$recitem | add-member -membertype noteproperty -name policyInfo -value $($backupitem.policyInfo)
$recitem | add-member -membertype noteproperty -name policyName -value $($backupitem.policyName)
$recitem | add-member -membertype noteproperty -name protectedItemType -value $($backupitem.protectedItemType)
$recitem | add-member -membertype noteproperty -name protectedPrimaryRegion -value $($backupitem.protectedPrimaryRegion)
$recitem | add-member -membertype noteproperty -name protectionState -value $($backupitem.protectionState)
$recitem | add-member -membertype noteproperty -name protectionStateInSecondaryRegion -value $($backupitem.protectionStateInSecondaryRegion)
$recitem | add-member -membertype noteproperty -name protectionStatus -value $($backupitem.protectionStatus)
$recitem | add-member -membertype noteproperty -name resourceGuardOperationRequests -value $($backupitem.resourceGuardOperationRequests)
$recitem | add-member -membertype noteproperty -name rpoWarningThresholdInPrimaryRegion -value $($backupitem.rpoWarningThresholdInPrimaryRegion)
$recitem | add-member -membertype noteproperty -name rpoWarningThresholdInSecondaryRegion -value $($backupitem.rpoWarningThresholdInSecondaryRegion)
$recitem | add-member -membertype noteproperty -name softDeleteRetentionPeriod -value $($backupitem.softDeleteRetentionPeriod)
$recitem | add-member -membertype noteproperty -name sourceResourceId -value $($backupitem.sourceResourceId)
$recitem | add-member -membertype noteproperty -name sourceSideScanInfo -value $($backupitem.sourceSideScanInfo)
$recitem | add-member -membertype noteproperty -name vaultId -value $($backupitem.vaultId)
$recitem | add-member -membertype noteproperty -name workloadType -value $($backupitem.workloadType)




[array]$protecteditems += $recitem



}





$protecteditems | Select allowedOperations,`
backupManagementType,`
backupSetName,`
configuredMaximumRetention,`
configuredMaximumRetentionInSecondaryRegion,`
configuredRPGenerationFrequency,`
configuredRPGenerationFrequencyInSecondaryRegion,`
containerName,`
createMode,`
currentProtectionState,`
dataSourceId,`
dataSourceInfo,`
dataSourceInfo.datasourceType,`
dataSourceInfo.resourceID,`
dataSourceInfo.resourceLocation,`
dataSourceSetInfo,`
deferredDeleteTimeInUTC,`
deferredDeleteTimeRemaining,`
extendedInfo,`
extendedInfo.oldest.RecoveryPoint,`
extendedInfo.oldest.recoveryPointCount,`
extendedInfo.oldestrecovery.oldestRecoveryPoint,`
friendlyName,`
isArchiveEnabled,`
isAzureManagedLinkedResource,`
isDatasourceDeleted,`
isDeferredDeleteScheduleUpcoming,`
isInlineInquiry,`
isRehydrate,`
isScheduledForDeferredDelete,`
kpisHealths,`
lastBackupStatus,`
lastBackupTime,`
lastRecoveryPoint,`
latestRecoveryPointInSecondaryRegion,`
oldestRecoveryPointInSecondaryRegion,`
policyId,`
policyInfo,`
policyName,`
protectedItemType,`
protectedPrimaryRegion,`
protectionState,`
protectionStateInSecondaryRegion,`
protectionStatus,`
resourceGuardOperationRequests,`
rpoWarningThresholdInPrimaryRegion,`
rpoWarningThresholdInSecondaryRegion,`
softDeleteRetentionPeriod,`
sourceResourceId,`
sourceSideScanInfo,`
vaultId,`
workloadType` |   Export-Csv -Path  "c:\temp\protecteditems.csv" -NoTypeInformation




# Generate HTML report
$date = Get-Date -Format 'dd MMMM yyyy'
$CSS = @"
<Title> Azure Recovery services items Report: $date </Title>
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

$htmlContent = @"
<h2>Azure Recovery services items Report</h2>
<p>Date: $date</p>
<p> </p>
"@ + ($protecteditems | Select allowedOperations,`
backupManagementType,`
backupSetName,`
configuredMaximumRetention,`
configuredMaximumRetentionInSecondaryRegion,`
configuredRPGenerationFrequency,`
configuredRPGenerationFrequencyInSecondaryRegion,`
containerName,`
createMode,`
currentProtectionState,`
dataSourceId,`
dataSourceInfo,`
dataSourceInfo.datasourceType,`
dataSourceInfo.resourceID,`
dataSourceInfo.resourceLocation,`
dataSourceSetInfo,`
deferredDeleteTimeInUTC,`
deferredDeleteTimeRemaining,`
extendedInfo,`
extendedInfo.oldest.RecoveryPoint,`
extendedInfo.oldest.recoveryPointCount,`
extendedInfo.oldestrecovery.oldestRecoveryPoint,`
friendlyName,`
isArchiveEnabled,`
isAzureManagedLinkedResource,`
isDatasourceDeleted,`
isDeferredDeleteScheduleUpcoming,`
isInlineInquiry,`
isRehydrate,`
isScheduledForDeferredDelete,`
kpisHealths,`
lastBackupStatus,`
lastBackupTime,`
lastRecoveryPoint,`
latestRecoveryPointInSecondaryRegion,`
oldestRecoveryPointInSecondaryRegion,`
policyId,`
policyInfo,`
policyName,`
protectedItemType,`
protectedPrimaryRegion,`
protectionState,`
protectionStateInSecondaryRegion,`
protectionStatus,`
resourceGuardOperationRequests,`
rpoWarningThresholdInPrimaryRegion,`
rpoWarningThresholdInSecondaryRegion,`
softDeleteRetentionPeriod,`
sourceResourceId,`
sourceSideScanInfo,`
vaultId,`
workloadType`  | ConvertTo-Html -Head $CSS)

$outputHtmlPath = "c:\temp\Azure_Recovery_services_items.html"
$htmlContent | Out-File -FilePath $outputHtmlPath


# Open the HTML report
Invoke-Item -Path $outputHtmlPath


