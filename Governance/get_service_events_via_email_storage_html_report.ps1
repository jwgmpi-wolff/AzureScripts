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

    #############

    Description: This script is designed to manage Azure modules, connect to an Azure account, 
    query for service health events, and send notifications via email. It also archives the results 
    in a storage account. The script performs the following tasks:

    Set Maximum Variable and Function Counts: Sets the maximum variable and function counts to 8192.
    Module Management: Checks if specific Azure modules (Az.Communication, az, Az.ResourceGraph, az.keyvault) 
    are installed. If they exist, they are updated; if not, they are installed and imported.
    Connect to Azure Account: Connects to an Azure account using managed identity.
    Query for Service Health Events: Defines and runs a query to find resources with potential cost issues 
    related to service health events.
    Process Query Results: Processes the query results, cleans up HTML tags from descriptions and summaries, 
    and stores the results in a CSV file.
    Generate HTML Report: Generates an HTML report of the service health events.
    Send Email Notification: Sends an email with the HTML report and CSV file as attachments.
    Archive Results in Storage Account: Archives the results in a specified Azure storage account.
    Function Use:
    send_custom_message: This function sends an email with the specified parameters including image path,
     recipient, subject, message text, file path, and HTML content. It retrieves the service principal and 
     secret from Key Vault, constructs the email message, 
    and sends it using the Azure Communication Service.

 #>
 
 
 
 
 $MaximumVariableCount = 8192
 $MaximumFunctionCount = 8192
   
  
  'Az.Communication', 'az','Az.ResourceGraph',  'az.keyvault' | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         #update-module $_ -force -ErrorAction Ignore |out-null 
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
       # install-module -name $_ -allowclobber | out-null
        import-module -name $_ -force | out-null
    }
   #  Get-InstalledModule
}

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
 






#######################################################################
    $resultsfilename = 'servicehealth_events.csv' 

$service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime `
 | export-csv $resultsfilename -NoTypeInformation




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




( $service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime, impactedresources `
| ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\servicehealth_events.html"


invoke-item "c:\temp\servicehealth_events.html"

###### Html for email 


$resultsfilenamehtml = ( $service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime, impactedresources `
| ConvertTo-Html -Head $CSS )  

###################
 ## 
#### Send via email 
Set-azconfig -DefaultSubscriptionForLogin '' 
    
$logincontext =    connect-azaccount -Identity

function send_custom_message  
{


    param (
        [string]$imagepath,
        [string]$to,
        [string]$subject,
        [string]$messagetext,
        [string]$filepath,
        [string] $resultsfilenamehtml
    )


    $vaultname = 'wolffkv'
    $spnname = 'wolffcommsvcspn'

    # Retrieve the service principal
    $serviceprincipal = Get-AzADServicePrincipal -DisplayName "$spnname"

    # Retrieve the secret from Key Vault
    $credsecret = Get-AzKeyVaultSecret -VaultName "$vaultname" -Name "$($serviceprincipal.AppId)" -AsPlainText

    # Retrieve the client key info from Key Vault
    $clientkeyinfo = Get-AzKeyVaultKey -VaultName "$vaultname" -Name "$($serviceprincipal.DisplayName)"

    # Convert the secret to a secure string
    $secureSecretValue = ConvertTo-SecureString -String "$credsecret" -AsPlainText -Force


    # Assuming $secureSecretValue is already a SecureString
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$($clientkeyinfo.Id)",$secureSecretValue


    #$from = "DoNotReply@dd688cae-f235-4138-9b3f-5caae105b7d2.azurecomm.net"
    $from = "DoNotReply@wolffentp.org"

    $subject = " Alert notification  for $spnname "
 
    # Define the email message

$File = if ($filepath) { [System.IO.File]::ReadAllBytes("$filepath") } else { $null }

        if ($imagepath) {
            try {
                $Image = [System.IO.File]::ReadAllBytes("$imagepath")
            } catch {
                write-warning "No images found"
                $Image = $null
            }
        }

        $emailAttachment = @()

        if ($File) {
            $emailAttachment += @{
                ContentInBase64 = $File
                ContentType = "text/html"
                Name = "$filepath"
            }
        }

        if ($Image) {
            $emailAttachment += @{
                ContentInBase64 = $Image
                ContentType = "image/png"
                Name = "$imagepath"
                contentId = "$($Image.id)"
            }
        } else {
            write-warning "Skipping, no images included"
        }


    $emailRecipientTo = @(
       @{
            Address = "$to"
            DisplayName = "Automation"
        }
    )

    $message = @{
	    ContentSubject = "$subject"
	    RecipientTo = @($emailRecipientTo)  # Array of email address objects
	    SenderAddress = "$from"	
	    ContentPlainText = "$messaagetext"	
        Attachment = @($emailAttachment) # Array of attachments
        ContentHtml = "$resultsfilenamehtml"

    }

    # Send the email
    Send-AzEmailServicedataEmail  -Message $message  -Endpoint "https://wolffacs.unitedstates.communication.azure.com/"

}

 send_custom_message  -resultsfilenamehtml $resultsfilenamehtml  -filepath "$resultsfilename" -messagetext "Service events affecting  $($azcontext.Context.Tenant.id)" -subject "Azure service health events" -to "jerrywolff@microsoft.com"





#######################################################################
####  For storage account archiving 

$Region = "westus"

 $subscriptionselected = 'wolffentpsub'



$service_events | select Eventtype ,status,description,trackingId, summary, priority, impactStartTime  ,impactMitigationTime, impactedresources `
 | export-csv $resultsfilename -NoTypeInformation
  
$Region = "West US"
$subscriptionselected = 'wolffentpSub'
$subscriptioninfo = get-azsubscription -subscriptionname $subscriptionselected
$resourcegroupname = 'wolffautomationrg'
$storageaccountname = 'wolffautosa'
$storagecontainer = 'servicehealthevents'

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($azcontext.context.tenant.id)

## un block storage 
# Enable Allow Storage Account Key Access
$scope = "/subscriptions/$($subscriptioninfo.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Storage/storageAccounts/$storageaccountname"

 
 

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
        










