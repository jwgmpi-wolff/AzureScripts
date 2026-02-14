# Connect to Azure account
Connect-AzAccount -identity 

$groupresourcesummary = ''
# Get all resources in the tenant
$resources = Get-AzResource 

# Group resources by type
$groupedResources = $resources | Group-Object -Property ResourceType
 
foreach($group in $groupedResources)
{

    $resgrpobj = new-object PSOBject

    $resgrpobj | Add-Member -MemberType NoteProperty -name  Name  -Value  $($group.name) 
     $resgrpobj | Add-Member -MemberType NoteProperty -name Group    -Value $($group.values)
      $resgrpobj | Add-Member -MemberType NoteProperty -name count   -Value $($group.count)
 

    [array]$groupresourcesummary += $resgrpobj

     

}





$CSS = @"

<Title>Azure Tenant Resources : $(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure Tenant Resources : $(Get-Date -Format 'dd MMMM yyyy')  </H2>

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




($groupresourcesummary  |  select name ,group, count | sort-object resourcetype |`
 ConvertTo-Html -Head $CSS ) `
|  Out-File "c:\temp\tenant_resources_counts.html"

Invoke-Item "c:\temp\tenant_resources_counts.html"









