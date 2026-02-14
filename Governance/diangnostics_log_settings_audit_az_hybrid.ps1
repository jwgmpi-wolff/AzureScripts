# Connect to Azure
 Connect-AzAccount -Identity

az login --identity

# Get all subscriptions
$subscriptions = Get-AzSubscription 
$results = ''

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $($sub.Id)

    # Get all resources in the subscription
    $resources = Get-AzResource | Where-Object {$_.ResourceType -eq "Microsoft.Storage/storageAccounts"}

    foreach ($resource in $resources) {
        #$diagSettings = Get-AzDiagnosticSetting -ResourceId $resource.ResourceId -ErrorAction Ignore
        $diagSettings = az monitor diagnostic-settings list --resource $resource.ResourceId | ConvertFrom-Json
       
          $diagSettings

          $diagSettings.metrics.retentionpolicy.days | fl *

        foreach ($setting in $diagSettings) {
            foreach ($log in $setting.metrics) {
                # Create a PSObject for each log entry
                $logObj = New-Object PSObject
                $logObj | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $($sub.Name)
                $logObj | Add-Member -MemberType NoteProperty -Name "ResourceName" -Value $($resource.Name)
                $logObj | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $($resource.ResourceType)
                $logObj | Add-Member -MemberType NoteProperty -Name "ResourceGroup" -Value $($resource.ResourceGroupName)
                $logObj | Add-Member -MemberType NoteProperty -Name "DiagnosticName" -Value $($setting.Name)
                $logObj | Add-Member -MemberType NoteProperty -Name "StorageAccountId" -Value $($setting.Id)
                $logObj | Add-Member -MemberType NoteProperty -Name "LogCategory" -Value $($log.Category)
                $logObj | Add-Member -MemberType NoteProperty -Name "LogEnabled" -Value $($log.Enabled)
                $logObj | Add-Member -MemberType NoteProperty -Name "RetentionEnabled" -Value $($log.RetentionPolicy.enabled)
                $logObj | Add-Member -MemberType NoteProperty -Name "RetentionDays" -Value $($log.RetentionPolicy.days)
                $logObj | Add-Member -MemberType NoteProperty -Name "Destinationtype" -Value $($Setting.type)

                
            }
               [array]$results += $logObj     
                
        }
            
    }
}

# Export results to CSV
$results | select  SubscriptionName, ResourceName, ResourceType, ResourceGroup,DiagnosticName , StorageAccountId,LogCategory, LogEnabled,RetentionEnabled, RetentionDays,Destinationtype | Export-Csv -Path "c:\temp\LegacyDiagnosticSettings.csv" -NoTypeInformation

Write-Host "Scan complete. Results saved to LegacyDiagnosticSettings.csv"



$CSS = @"
<Title>Diagnostic Logs settings Audit Report: $(Get-Date -Format 'dd MMMM yyyy') - Compliance Status</Title>
<Header>
<B>Company Confidential - NSG Audit Report: $(Get-Date -Format 'dd MMMM yyyy')</B> 
<I>Report generated from {3} on $env:computername {0} by {1}\{2} as a scheduled task</I>

Please contact $contact with any questions "$(Get-Date -displayhint date)",$env:userdomain,$env:username
</Header>
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
    color: #0000FF;
}
</Style>
"@

$Diagnostic_report = ($results | Sort-Object -Property SubscriptionName, ResourceName, ResourceType, ResourceGroup,DiagnosticName , StorageAccountId,LogCategory, LogEnabled,RetentionEnabled, RetentionDays,Destinationtype | ConvertTo-Html -Head $CSS)  

$Diagnostic_report | Out-File c:\temp\diag_logs_settings.html 
invoke-item  c:\temp\diag_logs_settings.html

 