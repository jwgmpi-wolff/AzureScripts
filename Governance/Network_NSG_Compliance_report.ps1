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


#> 









connect-azaccount -identity


$subs = Get-AzSubscription 

foreach ($sub in $subs) {
    Set-AzContext -Subscription $sub.Name -Verbose

    $niclist = Get-AzNetworkInterface

    foreach ($nic in $niclist) {
        $nic = Get-AzNetworkInterface -Name $nic.Name -ResourceGroupName $nic.ResourceGroupName
        $nsg = $nic.NetworkSecurityGroup

        $nsgname = if ($nsg -ne $null) { ($nsg.Id).Split("/")[-1] } else { 'None Assigned' }
        $nicname = $nic.Name
        $resourcegroup = $nic.ResourceGroupName

        $vm = if ($nic.VirtualMachine.Id -ne $null) { ($nic.VirtualMachine.Id).Split("/")[-1] } else { 'PIP Orphaned' }

        $PublicIPS = Get-AzPublicIpAddress -ResourceGroupName $resourcegroup | Where-Object { ($_.Id).Split("/")[-1] -like "$vm*" } -ErrorAction SilentlyContinue
        $PIP = $PublicIPS.Where({ $_.Id -eq $nic.IpConfigurations.PublicIpAddress.Id }).IpAddress

        $vmobj = New-Object PSObject
        $vmobj | Add-Member -MemberType NoteProperty -Name SubscriptionName -Value $sub.Name
        $vmobj | Add-Member -MemberType NoteProperty -Name resourcegroupname -Value $resourcegroup
        $vmobj | Add-Member -MemberType NoteProperty -Name VMName -Value $vm
        $vmobj | Add-Member -MemberType NoteProperty -Name vmloc -Value $nic.Location
        $vmobj | Add-Member -MemberType NoteProperty -Name NIC -Value $nicname
        $vmobj | Add-Member -MemberType NoteProperty -Name NetworsecurityGroup -Value $nsgname
        $vmobj | Add-Member -MemberType NoteProperty -Name publicipaddress -Value $PIP

        [array]$nsgaudit += $vmobj
    }
}

$CSS = @"
<Title>Non Compliant NSG Audit Report:$(Get-Date -Format 'dd MMMM yyyy' ) Must be remedied ASAP !!! </Title>
<Header>
 
"<B>Company Confidential - Non Compliant NSG Audit Report:$(Get-Date -Format 'dd MMMM yyyy' ) Must be remedied ASAP !!!</B> <br><I>Report generated from {3} on $env:computername {0} by {1}\{2} as a scheduled task</I><br><br>Please contact $contact with any questions "$(Get-Date -displayhint date)",$env:userdomain,$env:username
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

$nsgaudit_Compliance_Report = ((($nsgaudit | Sort-Object -Property SubscriptionName,resourcegroupname,VMName,vmloc,NIC,NetworsecurityGroup,publicipaddress |`
Select SubscriptionName,resourcegroupname, VMName,vmloc,NIC,@{Name='NetworsecurityGroup';E={IF ($_.NetworsecurityGroup -eq 'None Assigned' -and $_.publicipaddress -ne ''){'not Compliant'}Else{$_.NetworsecurityGroup}}},publicipaddress |`
where-object NetworsecurityGroup -eq 'not Compliant' |`
ConvertTo-Html -Head $CSS ).replace('not enabled','<font color=red>not enabled</font>'))).replace('not Compliant','<font color=red>not Compliant</font>')

$nsgaudit_Compliance_Report | Out-File c:\temp\nsg_compliance_report.html 
invoke-item  c:\temp\nsg_compliance_report.html

<#

function Send_report {
    $contact = "<a href='mailto:OpsTeam@.com'>ResponsibleTeam</a>"
    $sender = "task-service@.com"
    [string]$body2 = "$nsgaudit_Compliance_Report"
    $subject = "NSG Audit Report for period $dates"
    Send-MailMessage -To $recipients -From $sender -Subject "$subject" -Body $body2 -BodyAsHtml -SmtpServer smarthost.corp..local
}

$recipients = "OpsTeam@.com","devleads@.com","devopsteam@.com"
Send_report
#>

>