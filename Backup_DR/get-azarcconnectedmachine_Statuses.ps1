
Connect-AzAccount

import-module Az.ConnectedMachine 

$subscriptions = Get-AzSubscription -SubscriptionName wolffentpsub



$archybridvmstatus = ''



foreach ($subscription in $subscriptions)
{
    # Select a subscription
    Set-AzContext -SubscriptionId $($subscription.id) 


 #       $vmList = Get-AzResource -ResourceType Microsoft.HybridCompute/machines -ExpandProperties #| Where-Object {$_.Properties.osType -eq "hybrid"} | ForEach-Object {
      #  $vmList = Get-AzResource -ResourceType Microsoft.HybridCompute/machines -ExpandProperties   | ForEach-Object {
     $resources = (Get-AzConnectedMachine) | Select *
     ($resources).GetEnumerator() | ForEach-Object {
          $vmName = $_.Name
            
               $vmextensions = Get-AzConnectedMachineExtension -ResourceGroupName $($_.resourcegroupname) -MachineName $($_.Name)
                 
                    # Get-AzConnectedPrivateLinkScope -ResourceGroupName $($_.Name) #-SubscriptionId $($subscription.id) 
                 start-job  "Invoke-AzConnectedAssessMachinePatch -Name $($_.Name) -ResourceGroupName $($_.resourcegroupname)"
  


                foreach($vmextension in $vmextensions)
                {
                    $arcvmobj = new-object PSObject 

                     $arcvmobj | Add-Member -MemberType NoteProperty -name Vmname  -value $($_.Name)
                     $arcvmobj | Add-Member -MemberType NoteProperty -name Resourcegroup  -value $($vmextension.resourcegroupname)
                     $arcvmobj | Add-Member -MemberType NoteProperty -name  Extensionname -value $($vmextension.name)
                     $arcvmobj | Add-Member -MemberType NoteProperty -name location  -value $($vmextension.location)
                     $arcvmobj | Add-Member -MemberType NoteProperty -name TypeHandlerVersion  -value $($vmextension.TypeHandlerVersion)
                     $arcvmobj | Add-Member -MemberType NoteProperty -name ProvisioningState  -value $($vmextension.ProvisioningState)
                     $arcvmobj | Add-Member -MemberType NoteProperty -name  Publisher -value $($vmextension.Publisher)      
             
                   [array]$archybridvmstatus += $arcvmobj  
                                                                                   
                }
        }
}



$archybridvmstatus

