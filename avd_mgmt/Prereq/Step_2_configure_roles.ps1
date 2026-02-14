######### Must be run with user having Resourcegroup owner or VM owner  - Role addtions for Managed Identities

$vmName = "$env:computername"

 
#############################  Admin account must be used 
 $account = connect-azaccount         #-Environment AzureUSGovernment 

 $sub = get-azsubscription -SubscriptionName $($account.Context.Subscription.Name)

 set-azcontext -Subscription $($sub.Name) | out-null

  
########################
 $vminfo = get-azvm -name $VMNAME

$resourceGroup = "$($vminfo.ResourceGroupName)"
$location =  "$($vminfo.Location)"


$managedidfound = Get-AzADServicePrincipal -SearchString $($account.Context.account)
$managedid = (Get-AzADServicePrincipal -DisplayName $($vminfo.Name)).id

 $roles = Get-AzRoleDefinition | where-object { $_.Name -eq 'Virtual Machine Contributor' -or $_.name -eq 'Desktop Virtualization Power On Off Contributor' -or $_.name -eq 'Desktop Virtualization Virtual Machine Contributor' -or $_.name -eq 'Desktop Virtualization Session Host Operator'} | select  Name, Id

  
 
Update-AzVM `
    -VM  $vminfo `
    -IdentityType SystemAssigned `
    -ResourceGroupName "$($vminfo.ResourceGroupName)"

 $vmsystemid = get-azvm -name $VMNAME | select -ExpandProperty identity

foreach($role in $roles)
{

New-AzRoleAssignment -ObjectId  $($vmsystemid.PrincipalId) `
-RoleDefinitionName $($role.name) `
-ResourceGroupName $($vminfo.ResourceGroupName) #-Verbose -Debug
}


Get-AzRoleAssignment -ObjectId $($vmsystemid.PrincipalId) | select  displayname, RoleDefinitionName -Unique



















