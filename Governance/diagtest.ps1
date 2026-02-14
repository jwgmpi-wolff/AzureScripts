




$results = ''
# Variables
$resourceGroupName = "wolffcentralusrg"
$storageAccountName = "wolffcentralsa"

Connect-AzAccount -Identity
az login --identity

  # Get all resources in the subscription
    #$resources = Get-AzResource  | where name -eq $storageAccountName 


set-azcontext -subscription wolffentpsub






    # Get all resources in the subscription
    $resources = Get-azstorageaccount  | where StorageAccountName -eq $storageAccountName 
    $resources  
 

    foreach ($resource in $resources) {
         $armdiagSettings = Get-AzDiagnosticSetting -ResourceId $resource.id -ErrorAction Ignore
        $armdiagSettings
      #  $diagSettings = az monitor diagnostic-settings list --resource $resource.id | ConvertFrom-Json
      #    $diagSettings
          $diagSettings.metrics.retentionpolicy.days | fl *
        foreach ($setting in $armdiagSettings) {
            foreach ($log in $setting.metrics) {
                # Create a PSObject for each log entry
                $logObj = New-Object PSObject
                $logObj | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $($sub.Name)
                $logObj | Add-Member -MemberType NoteProperty -Name "ResourceName" -Value $($resource.StorageAccountName)
                $logObj | Add-Member -MemberType NoteProperty -Name "ResourceType" -Value $($resource.kind)
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

$results







