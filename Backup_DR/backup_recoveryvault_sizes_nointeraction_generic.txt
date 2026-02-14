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
    Azure powershell script to retrieve Azure Recovery services vault usage counts by :
    The script imports the az.RecoveryServices module and suppresses the output using out-null.
It connects to Azure using connect-azaccount and retrieves the access token using Get-AzAccessToken.
It initializes the $vaultinfo variable.
It retrieves the list of subscriptions using get-azsubscription.
It selects the first subscription from the list.
It authenticates to Azure and sets the context to the selected subscription.
It defines a function BuildBody that takes a mandatory parameter method and returns a 
hashtable with headers and method. The headers contain the authorization token and the 
content type. The method is set to the value of the method parameter.
Finally collects all results, , generates and HTML report and A csv formatted report pushed to a storage account 


#>

import-module -name az.RecoveryServices | out-null


$connection = connect-azaccount  # -Environment AzureUSGovernment
$credential = Get-AzAccessToken


$vaultinfo = ''

$subscriptions = get-azsubscription

$subscriptionselected = $subscriptions #| ogv -Title " Select the subscription for the restoration process: " -PassThru | Select * -First 1

        
   foreach($subscription in $subscriptionselected)

  { 
  
              Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
                        try
                        {
                            $AzureLogin = Get-AzSubscription 
                            $currentContext = Get-AzContext
                            $token = Get-AzAccessToken -TenantId $($subscription.TenantId)
                            if($Token.ExpiresOn -lt $(get-date))
                            {
                                "Logging you out due to cached token is expired for REST AUTH.  Re-run script"
                                #$null = Disconnect-AzAccount        
                            } 
                  
                        }
                        catch
                        {

                            $AzureLogin = Get-AzSubscription  
                            $currentContext = Get-AzContext
                            $token = Get-AzAccessToken -TenantId $($subscription.TenantId)
    
                        }


            set-azcontext -Subscription $($subscription.name) 


 
            function BuildBody
            (
                [parameter(mandatory=$True)]
                [string]$method
            )
            {
                $BuildBody = @{
                Headers = @{
                    Authorization = "Bearer $($token.token)"
                    'Content-Type' = 'application/json'
                }
                Method = $Method
                UseBasicParsing = $true
                }
                $BuildBody
            }  
 
               $body = BuildBody GET


            $recoveryservicesvaults = Get-AzRecoveryServicesVault

            $vaultselected = $recoveryservicesvaults  

             foreach ($vault in $vaultselected)
             {
 

            $vault = Get-AzRecoveryServicesVault -ResourceGroupName $($vault.ResourceGroupName) -Name $($vault.Name) 

            Set-AzRecoveryServicesVaultContext -Vault $vault 
 
  



                $requesturi = "https://management.azure.com/Subscriptions/$($subscription.id)/resourceGroups/$($vault.ResourceGroupName)/providers/Microsoft.RecoveryServices/vaults/$($vault.Name)/usages?api-version=2023-04-01"

                     $response = Invoke-RestMethod -Uri $requestUri -Headers ($body.Headers)  -Method GET -ErrorAction silentlycontinue
                     #$response.value | fl *


                    # Output the response
                     $($response.value).GetEnumerator() | where-object {$($_.bytes).value -ne 0 }| ForEach-Object {


                         if($($_.currentvalue) -ne 0  )
                         {
                    
                           WRITE-HOST " $($_.unit) : $($_.currentvalue) : $($_.name.value)"
                           if($_.unit -eq 'Bytes')
                           {
                            $sizelabel = 'Size in GB'
                            $size = $($_.currentvalue) /1024 /1024 /1024
                            }
                            else
                            {
                                $sizelabel = "$($_.unit)"
                                $size = $($_.currentvalue)
                            }

                            $vaultobj = new-object PSObject 


                            $vaultobj | add-member -MemberType NoteProperty -Name Subscriptionname -value  $($subscription.name)
                            $vaultobj | add-member -MemberType NoteProperty -Name Vaultname -value  $($vault.Name)
                            $vaultobj | add-member -MemberType NoteProperty -Name Resourcegroupname -value $($vault.ResourceGroupName)                             
                            $vaultobj | add-member -MemberType NoteProperty -Name Vaultitem -Value $($_.name.value)
                            $vaultobj | add-member -MemberType NoteProperty -Name Unit -value $($_.unit) 
                            $vaultobj | add-member -MemberType NoteProperty -Name Size  -Value $size
                            $vaultobj | add-member -MemberType NoteProperty -Name Note  -Value $sizelabel 
                [array]$vaultinfo  += $vaultobj 

                         }

                     }


            }



}



 $date = $(Get-Date -Format 'dd MMMM yyyy' )
 
    $CSS = @"
<Title> Azure Recovery services Storage Report: $date </Title>
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


 

 
$AZrecoverystorage_report = ($vaultinfo    | Select  Subscriptionname, Vaultname , Resourcegroupname ,Vaultitem  ,Unit,`
size, note|`   
ConvertTo-Html -Head $CSS )  | out-file "c:\temp\AZrecoverystorage_report.html" 

invoke-item "c:\temp\AZrecoverystorage_report.html" 



#####################################################################################
 ######### Uncomment and configure to send results to storage account blob 


 
 $date = $(Get-Date -Format 'dd MMMM yyyy' )
 
########### Prepare for storage account export

$csvresults = $AZrecoverystorage_report = ($vaultinfo    | Select  Subscriptionname, Vaultname , Resourcegroupname ,Vaultitem  ,Unit,`
size, note | sort-object subscriptioname   |   Select  *)

 $resultsfilename = "azrecoverystorage.csv"

$csvresults  | export-csv $resultsfilename  -NoTypeInformation   

# end vmss data 


##### storage subinfo

$Region = "westus"
 $date = Get-Date -Format MMddyyyy
 $subscriptionselected = '<subsctiprionname>'



$resourcegroupname = '<Resourcegroupname>'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | select tenantid
$storageaccountname = '<storageaccountname>'
$storagecontainer = 'azrecoverystorage'
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
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfile  -File $resultsfilename -Context $destContext -FORCE
        
        
 
 





