
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

    Script Name: check_sku_quota_use_percentage
    Description: Custom script to check on quota percentage based on requested use 
    NOTE:   Scripts creates an HTML report with the percentage against requested amount and recommended amount to increase limit


#> 

####### Suppress powershell module changes warning during execution 

 
write-host ""
write-host ""
write-host " _                _          _         ____    ____       " -ForegroundColor Green
write-host " \\      /\      // _____   | |       |____|  |____|      " -ForegroundColor Yellow
write-host "  \\    //\\    // |  _  |  | |       | |__   | |__       " -ForegroundColor Red
write-host "   \\  //  \\  //  | | | |  | |       | ___|  | ___|      " -ForegroundColor Cyan
write-host "    \\//    \\//   | |_| |  | |____   | |     | |      " -ForegroundColor DarkCyan
write-host "     \/      \/    |_____|  |______|  |_|     |_|      "-ForegroundColor Magenta
write-host "     "
write-host " This script validates AzquotaUSage" -ForegroundColor "Green"


          Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
 
         #connect-azaccount  # -identity
              connect-azaccount -Environment AzureUSGovernment  # -identity

        ## Cleanup
 

        $usageSummary = $null 



        $subs = get-Azsubscription      
        
       $regions =   get-azlocation  

      foreach($sub in $subs)
      {
              $subid = $subb.id

         $subname  = $sub.name

                Set-Azcontext -subscriptionname  $subname   

            Get-AzAccessToken -TenantId $sub.TenantId | out-null
 

      foreach($location in  $regions)
      {

 

 

         $regionquotas =    Get-AzVmUsage –Location $($location.Location)    -ErrorAction SilentlyContinue
 
 

            foreach($regionquotausage in $regionquotas)
            {

                                    $vmobj = new-object PSObject 

                                        $usedCount = [int]($($regionquotausage.CurrentValue))   
                                        $quota = [int]($($regionquotausage.Limit))

                                        if ($quota -gt 0 -and $usedCount -gt 0)
                                        {
                                        $Percentage = ($usedCount / $quota) * 100
                                        }
                                        else
                                        {
                                            $Percentage = 0
                                        }

                                        If(($usedcount + $Corecountrequests) -gt $quota )
                                        {
 
                                         $Recommended_increase  = (($quota + $Corecountrequests) +  ($quota + $Corecountrequests) * (20/100) )

                                         }


                                        $vmobj | add-member  -membertype NoteProperty -name   Subscription  -value "$subname" 
                                        $vmobj | add-member  -membertype NoteProperty -name   Region  -value "$($location.Location)"                                                                                    
                                        $vmobj | add-member  -membertype NoteProperty -name   ResourceNameValue  -value "$($regionquotausage.Name.Value)"  
                                        $vmobj | add-member  -membertype NoteProperty -name   ResourceNameLocalizedValue  -value "$($regionquotausage.Name.LocalizedValue)"                                                                         
                                        $vmobj | add-member  -membertype NoteProperty -name   CurrentCount  -value "$($regionquotausage.CurrentValue)"         
                                        $vmobj | add-member  -membertype NoteProperty -name   Limit  -value "$($regionquotausage.Limit)"  
                                                
                                        $vmobj | add-member  -membertype NoteProperty -name   Percentage_used   -value    $Percentage   
                                     


                                  [array]$usageSummary +=  $vmobj 
               } 
    }       
}
       
 

$CSS = @"

<Title>Azure Resource Usage  Warning  Report:$(Get-Date -Format 'dd MMMM yyyy') </Title>

    <H2>Azure Resource Usage Warning  Report:$(Get-Date -Format 'dd MMMM yyyy')  </H2>

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



        ########read in collected results and create the html report

        $usagereport = $usageSummary
 
 
        $usage_report_detail = ((($usagereport   | Sort-Object -Property Subscription,Region,ResourceNameValue,ResourceNameLocalizedValue,CurrentCount,Limit -Unique |`
        Select Subscription, Region,ResourceNameValue,ResourceNameLocalizedValue,@{Name='CurrentCount';E={IF ($_.CurrentCount -eq '0'){'unused'}Else{$_.CurrentCount}}},Limit,@{Name='Percentage_used';E={IF ($_.Percentage_used -ge $percentagelimit){" $($_.Percentage_used)" }Else{$_.Percentage_used}}}  |`
        ConvertTo-Html -Head $CSS ).replace('unused','<font color=red>0</font>')).replace('Running_out',"<font color=$($_.Percentage_used) %</font>"))  
        
        $usage_report_detail | Out-File "c:\temp\quota_check.html"
 
 invoke-item "c:\temp\quota_check.html"

  
        $usage_report_detail = ((($usagereport | where currentcount -ne 0  | Sort-Object -Property Subscription,Region,ResourceNameValue,ResourceNameLocalizedValue,CurrentCount,Limit -Unique |`
        Select Subscription, Region,ResourceNameValue,ResourceNameLocalizedValue,@{Name='CurrentCount';E={IF ($_.CurrentCount -eq '0'){'unused'}Else{$_.CurrentCount}}},Limit,@{Name='Percentage_used';E={IF ($_.Percentage_used -ge $percentagelimit){" $($_.Percentage_used)" }Else{$_.Percentage_used}}}  |`
        ConvertTo-Html -Head $CSS ).replace('unused','<font color=red>0</font>')).replace('Running_out',"<font color=$($_.Percentage_used) %</font>"))  
        
        $usage_report_detail | Out-File "c:\temp\quota_check_for_used_resources.html"
 
 invoke-item "c:\temp\quota_check_for_used_resources.html"


 
 $resultsfilename = 'quota_check_audit.csv'


 $usagereport   | Sort-Object -Property Subscription,Region,ResourceNameValue,ResourceNameLocalizedValue,CurrentCount,Limit -Unique |`
        Select Subscription, Region,ResourceNameValue,ResourceNameLocalizedValue,@{Name='CurrentCount';E={IF ($_.CurrentCount -eq '0'){'0'}Else{$_.CurrentCount}}},Limit,Percentage_used  `
        | export-csv "$resultsfilename" -NoTypeInformation


 ##### storage subinfo

$Region = "usgovarizona"

 $subscriptionselected = 'MSUSAZGOV'



$resourcegroupname = 'wolffgovautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffgovautoaccnt'
$storagecontainer = 'quotacheckcnt'


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
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -force
