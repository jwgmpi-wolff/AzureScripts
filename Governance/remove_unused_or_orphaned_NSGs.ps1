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
    Description: 

    Authenticates using managed identity.
    Audits all NSGs across all subscriptions.
    Checks for associated NICs and VMs.
    Generates a styled HTML report listing NSGs and their connected devices (or lack thereof).
    Opens the report for review.
#> 

connect-azaccount -Identity

$nsgsdeleted = ''
$nsgaudit = ''
$connectedDevices = ''

$subs = Get-AzSubscription

foreach ($sub in $subs) {
    Set-AzContext -Subscription $sub.Name -Verbose

   # $nsglist = Get-AzNetworkSecurityGroup

        # Check for associated NICs
        $niclist = Get-AzNetworkInterface 

 

        foreach ($nic in $niclist) 
        {
        $vmnic = get-aznetworkinterface -name $($nic.name) -ResourceGroupName $($nic.ResourceGroupName) 
        $vmname = get-azvm | where id -eq $($nic.virtualmachine.id) | select name
        if (!(get-azvm | where id -eq $($nic.virtualmachine.id) | select name)) 
        {

         $vritualmachine = "$($vmnic.Name) - orphaned"
         
         }
         else
         {
          $vritualmachine = $($vmname.name)
            
         }
            $networksecuritygroupname = ($($vmnic.networksecuritygroup.id) -split ('/'))[-1]
 

       $vmnicobj   = New-Object PSObject
  

        $vmnicobj | add-member -membertype noteproperty -name AuxiliaryMode -value $($vmnic.AuxiliaryMode)
        $vmnicobj | add-member -membertype noteproperty -name AuxiliarySku -value $($vmnic.AuxiliarySku)
        $vmnicobj | add-member -membertype noteproperty -name DefaultOutboundConnectivityEnabled -value $($vmnic.DefaultOutboundConnectivityEnabled)
        $vmnicobj | add-member -membertype noteproperty -name DisableTcpStateTracking -value $($vmnic.DisableTcpStateTracking)
        $vmnicobj | add-member -membertype noteproperty -name DnsSettings -value $($vmnic.DnsSettings)
        $vmnicobj | add-member -membertype noteproperty -name DnsSettingsText -value $($vmnic.DnsSettingsText)
        $vmnicobj | add-member -membertype noteproperty -name EnableAcceleratedNetworking -value $($vmnic.EnableAcceleratedNetworking)
        $vmnicobj | add-member -membertype noteproperty -name EnableIPForwarding -value $($vmnic.EnableIPForwarding)
        $vmnicobj | add-member -membertype noteproperty -name Etag -value $($vmnic.Etag)
        $vmnicobj | add-member -membertype noteproperty -name ExtendedLocation -value $($vmnic.ExtendedLocation)
        $vmnicobj | add-member -membertype noteproperty -name ExtendedLocationText -value $($vmnic.ExtendedLocationText)
        $vmnicobj | add-member -membertype noteproperty -name HostedWorkloads -value $($vmnic.HostedWorkloads)
        $vmnicobj | add-member -membertype noteproperty -name Id -value $($vmnic.Id)
        $vmnicobj | add-member -membertype noteproperty -name IpConfigurations -value $($vmnic.IpConfigurations)
        $vmnicobj | add-member -membertype noteproperty -name IpConfigurationsText -value $($vmnic.IpConfigurationsText)
        $vmnicobj | add-member -membertype noteproperty -name Location -value $($vmnic.Location)
        $vmnicobj | add-member -membertype noteproperty -name MacAddress -value $($vmnic.MacAddress)
        $vmnicobj | add-member -membertype noteproperty -name Name -value $($vmnic.Name)
        $vmnicobj | add-member -membertype noteproperty -name NetworkSecurityGroup -value  $networksecuritygroupname 
        $vmnicobj | add-member -membertype noteproperty -name NetworkSecurityGroupText -value $($vmnic.NetworkSecurityGroupText)
        $vmnicobj | add-member -membertype noteproperty -name Primary -value $($vmnic.Primary)
        $vmnicobj | add-member -membertype noteproperty -name PrivateEndpoint -value $($vmnic.PrivateEndpoint)
        $vmnicobj | add-member -membertype noteproperty -name PrivateEndpointText -value $($vmnic.PrivateEndpointText)
        $vmnicobj | add-member -membertype noteproperty -name ProvisioningState -value $($vmnic.ProvisioningState)
        $vmnicobj | add-member -membertype noteproperty -name ResourceGroupName -value $($vmnic.ResourceGroupName)
        $vmnicobj | add-member -membertype noteproperty -name ResourceGuid -value $($vmnic.ResourceGuid)
        $vmnicobj | add-member -membertype noteproperty -name Tag -value $($vmnic.Tag)
        $vmnicobj | add-member -membertype noteproperty -name TagsTable -value $($vmnic.TagsTable)
        $vmnicobj | add-member -membertype noteproperty -name TapConfigurations -value $($vmnic.TapConfigurations)
        $vmnicobj | add-member -membertype noteproperty -name TapConfigurationsText -value $($vmnic.TapConfigurationsText)
        $vmnicobj | add-member -membertype noteproperty -name Type -value $($vmnic.Type)
        $vmnicobj | add-member -membertype noteproperty -name VirtualMachine -value  $vritualmachine 
        $vmnicobj | add-member -membertype noteproperty -name VirtualMachineText -value $($vmnic.VirtualMachineText)
        $vmnicobj | add-member -membertype noteproperty -name VnetEncryptionSupported -value $($vmnic.VnetEncryptionSupported)

        [array]$connectedDevices += $vmnicobj
    
        }

   $connectedDevices | Select virtualmachine, NetworkSecurityGroup
}
 

 foreach($nsgitem in $($connectedDevices.NetworkSecurityGroup) | where-object { $_ -ne $null} )
 {
        $Assigned = if ($connectedDevices.Count -gt 0) { $connectedDevices -join ", " } else { "None Assigned" }

        $nsgobj = New-Object PSObject
        $nsgobj | Add-Member -MemberType NoteProperty -Name SubscriptionName -Value $sub.Name
        $nsgobj | Add-Member -MemberType NoteProperty -Name ResourceGroupName -Value $resourcegroup
        $nsgobj | Add-Member -MemberType NoteProperty -Name NSGName -Value $nsgname
        $nsgobj | Add-Member -MemberType NoteProperty -Name Assignment -Value $Assigned

        [array]$nsgaudit += $nsgobj
 

 

    }
 


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

$nsgaudit_assignment_report = ($nsgaudit | Sort-Object -Property SubscriptionName, ResourceGroupName, NSGName, Assigned | ConvertTo-Html -Head $CSS)

$nsgaudit_assignment_report | Out-File c:\temp\nsgaudit_Report.html 
invoke-item  c:\temp\nsgaudit_Report.html
 
 foreach($nsgna in ($nsgaudit | where Assignment -eq 'None Assigned') )
 {
    set-azcontext -Subscription $($nsgna.SubscriptionName) 

    Get-AzNetworkSecurityGroup -Name $($nsgna.NSGNAME) -ResourceGroupName $($nsgna.ResourceGroupName)  | remove-AzNetworkSecurityGroup -Verbose -force # -WhatIf 
     
     $nsgnaobj = New-Object PSObject
        $nsgnaobj | Add-Member -MemberType NoteProperty -Name SubscriptionName -Value $sub.Name
        $nsgnaobj | Add-Member -MemberType NoteProperty -Name ResourceGroupName -Value $resourcegroup
        $nsgnaobj | Add-Member -MemberType NoteProperty -Name NSGName -Value $nsgname
        $nsgnaobj | Add-Member -MemberType NoteProperty -Name Assignment -Value $Assigned
        $nsgnaobj | Add-Member -MemberType NoteProperty -Name Deletionstatus -Value "Deleteing/Deleted"
    [array]$nsgsdeleted += $nsgnaobj

 }

 $nsgsdeleted

 $nsgaudit_deletion_report = ($nsgsdeleted | Sort-Object -Property SubscriptionName, ResourceGroupName, NSGName, Assigned, Deletionstatus | ConvertTo-Html -Head $CSS)

$nsgaudit_deletion_report | Out-File c:\temp\nsgaudit_deletion_Report.html 
invoke-item  c:\temp\nsgaudit_deletion_Report.html


$nsgaudit_assignment_report = ($nsgaudit | Sort-Object -Property SubscriptionName, ResourceGroupName, NSGName, Assigned | ConvertTo-Html -Head $CSS)

$nsgaudit_assignment_report | Out-File c:\temp\nsgaudit_Report.html 
invoke-item  c:\temp\nsgaudit_Report.html
 



