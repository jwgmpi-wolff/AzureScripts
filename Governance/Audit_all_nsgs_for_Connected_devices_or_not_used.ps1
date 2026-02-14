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

Description : This PowerShell script performs an audit of all Azure Network Security Groups (NSGs) across selected subscriptions,
 identifying their associated network interfaces (NICs) and the virtual machines (VMs) managing those NICs. 
 The final output is a styled HTML report for compliance and visibility.
 
 
 #>
 
 
 
 
 
 $MaximumVariableCount = 8192
 $MaximumFunctionCount = 8192
  




connect-azaccount -Identity

  
  'microsoft.graph', 'Az.network'  | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         #update-module $_ -force
           import-module -name $_ -force
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
        install-module -name $_ -allowclobber
        import-module -name $_ -force
    }
   #  Get-InstalledModule
}

####################################################################


$connectedDevices = ''

$query = @"
resources
| where type == "microsoft.network/networksecuritygroups"
| project nsgId = id, nsgName = name, location, resourceGroup, subscriptionId
| join kind=leftouter (
    resources
    | where type == "microsoft.network/networkinterfaces"
    | extend nsgId = tostring(properties.networkSecurityGroup.id),
             nicName = name,
             vmId = tostring(properties.virtualMachine.id),
             vmName = tostring(split(properties.virtualMachine.id, "/")[8])
    | project nsgId, nicName, vmName
) on nsgId
| extend subscriptionId = tostring(subscriptionId)
| project subscriptionId, nsgName, location, resourceGroup, connectedNic = nicName, managingVm = vmName
| order by subscriptionId, nsgName asc
| order by ['connectedNic'] desc
"@

$NSGScan = Search-AzGraph -Query $query
 

 foreach($nsg in $nsgscan)
 {
 
       $vmnicobj   = New-Object PSObject
  

        $vmnicobj | add-member -membertype noteproperty -name Subscriptionid -value $($nsg.Subscriptionid)
        $vmnicobj | add-member -membertype noteproperty -name NSGName -value $($nsg.NSGName)
        $vmnicobj | add-member -membertype noteproperty -name Location -value $($nsg.Location)
        $vmnicobj | add-member -membertype noteproperty -name Resourcegroup -value $($nsg.Resourcegroup)
        $vmnicobj | add-member -membertype noteproperty -name ConnectedNic -value $($nsg.ConnectedNic)
        $vmnicobj | add-member -membertype noteproperty -name managingVm -value $($nsg.managingVm)
       
        [array]$connectedDevices += $vmnicobj
    
  }

  $connectedDevices



$CSS = @"
<Title>NSG Audit Report: $(Get-Date -Format 'dd MMMM yyyy') - Compliance Status</Title>
<Header>
<B>Company Confidential - NSG Audit Report: $(Get-Date -Format 'dd MMMM yyyy')</B> <br><I>Report generated from {3} on $env:computername {0} by {1}\{2} as a scheduled task</I><br><br>Please contact $contact with any questions "$(Get-Date -displayhint date)",$env:userdomain,$env:username
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

$nsgaudit_assignment_report = ($connectedDevices | Sort-Object -Property SubscriptionId, ResourceGroupName, NSGName, ConnectedNic,ManageingVM  | ConvertTo-Html -Head $CSS)  

$nsgaudit_assignment_report | Out-File c:\temp\nsgscan_Report.html 
invoke-item  c:\temp\nsgscan_Report.html



