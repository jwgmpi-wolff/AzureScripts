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

$subs = Get-AzSubscription

foreach ($sub in $subs) {
    Set-AzContext -Subscription $sub.Name -Verbose

    $nsglist = Get-AzNetworkSecurityGroup

    foreach ($nsg in $nsglist) {
        $nsgname = $nsg.Name
        $resourcegroup = $nsg.ResourceGroupName

        $connectedDevices = @()

        # Check for associated NICs
        $niclist = Get-AzNetworkInterface -ResourceGroupName $resourcegroup | Where-Object { $_.NetworkSecurityGroup.Id -eq $nsg.Id }
        foreach ($nic in $niclist) {
            $connectedDevices += $nic.Name
        }

        # Check for associated VMs
        $vmlist = Get-AzVM -ResourceGroupName $resourcegroup | Where-Object { $_.NetworkProfile.NetworkInterfaces.Id -contains $nsg.Id }
        foreach ($vm in $vmlist) {
            $connectedDevices += $vm.Name
        }

        $Assigned = if ($connectedDevices.Count -gt 0) { $connectedDevices -join ", " } else { "None Assigned" }

        $nsgobj = New-Object PSObject
        $nsgobj | Add-Member -MemberType NoteProperty -Name SubscriptionName -Value $sub.Name
        $nsgobj | Add-Member -MemberType NoteProperty -Name ResourceGroupName -Value $resourcegroup
        $nsgobj | Add-Member -MemberType NoteProperty -Name NSGName -Value $nsgname
        $nsgobj | Add-Member -MemberType NoteProperty -Name Assignment -Value $Assigned

        [array]$nsgaudit += $nsgobj
    }
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
 




