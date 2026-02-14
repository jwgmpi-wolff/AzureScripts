# Connect to your cloud service account
$azcontext = Connect-AzAccount -identity
 

$service_events = ''



# Define the query to find resources with potential cost issues
$query = @"
ServiceHealthResources
| where type =~ 'Microsoft.ResourceHealth/events'
| extend eventType = tostring(properties.EventType), status = properties.Status, description = properties.Title, trackingId = properties.TrackingId, summary = properties.Summary, priority = properties.Priority, impactStartTime = todatetime(properties.ImpactStartTime), impactMitigationTime = todatetime(properties.ImpactMitigationTime)
| project eventType, status, description, trackingId, summary, priority, impactStartTime, impactMitigationTime
"@

# Run the query
$results = Search-AzGraph -Query $query

# Display the results
$results 
 
foreach($event in $results)
{
    $descriptions   = $($event.description) -replace "<.*?>", ""
    $summary =  $($event.summary) -replace "<.*?>", ""
 
 


    $eventobj = new-object PSObject 

    $eventobj | add-member -MemberType NoteProperty -Name Eventtype -Value $($event.eventtype)
    $eventobj | add-member -MemberType NoteProperty -Name status -Value $($event.status)
    $eventobj | add-member -MemberType NoteProperty -Name description -Value  "$descriptions"
    $eventobj | add-member -MemberType NoteProperty -Name trackingId -Value $($event.trackingId)
    $eventobj | add-member -MemberType NoteProperty -Name summary -Value "$summary"
    $eventobj | add-member -MemberType NoteProperty -Name priority   -Value $($event.priority)
    $eventobj | add-member -MemberType NoteProperty -Name impactStartTime  -Value $($event.impactStartTime)
    $eventobj | add-member -MemberType NoteProperty -Name impactMitigationTime  -Value $($event.impactMitigationTime)

    [array]$service_events += $eventobj


    
}


$service_events 




$CSS = @"

<Title>Azure service health events : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure service health events : $(Get-Date -Format 'dd MMMM yyyy')  </H2>

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




( $service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\servicehealth_events.html"


invoke-item "c:\temp\servicehealth_events.html"
###################
## exceptions only

($service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\servicehealth_events.html"


invoke-item "c:\temp\servicehealth_events.html"




#######################################################################
####  For storage account archiving 

$Region = "westus"

 $subscriptionselected = 'wolffentpsub'





 $resultsfilename = 'servicehealth_events.csv'


$service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime `
 | export-csv $resultsfilename -NoTypeInformation




$Region = "West US"
$subscriptionselected = 'wolffentpSub'
$subscriptioninfo = get-azsubscription -subscriptionname $subscriptionselected
$resourcegroupname = 'wolffautomationrg'
$storageaccountname = 'wolffautosa'
$storagecontainer = 'servicehealtheventsall'

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($azcontext.context.Tenant.Id)

## un block storage 
# Enable Allow Storage Account Key Access
$scope = "/subscriptions/$($subscriptioninfo.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

$servicePrincipal = Get-AzADServicePrincipal -DisplayName "$($azcontext.Account)"

# Display the service principal's Object ID
$servicePrincipal.Id

 

Set-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname -AllowBlobPublicAccess $true -AllowSharedKeyAccess $true  -force

 $destContext = New-AzStorageContext -StorageAccountName "$storageaccountname" -StorageAccountKey ((Get-AzStorageAccountKey -ResourceGroupName "$resourcegroupname" -Name $storageaccountname).Value | select -first 1)


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


             #Upload user.csv to storage account

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
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -force
        
 
 
 









