Import-Module Az -force


Connect-azaccount -Identity
  

set-azcontext -Subscription wolffsecsub



#$ManagementGroup = Get-AzManagementGroup -GroupName 'secadminmg'

$group = Get-AzADGroup -DisplayName 'dnsadmins'

$serviceprincipal = Get-AzADServicePrincipal | where displayname -eq 'wolffcommsvcspn' | Select DisplayName, Id, AppId


$Assignment = Get-AzPolicyAssignment  | where displayname -eq 'create_resource_block_with_exclusions' | select -First 1
New-AzPolicyExemption -Name 'Adminsallowedcreate' -PolicyAssignment $Assignment -Scope $($group.id) -ExemptionCategory   Waiver



$Assignment = Get-AzPolicyAssignment  | where displayname -eq 'create_resource_block_with_exclusions' | select -First 1
New-AzPolicyExemption -Name 'Adminsallowedcreate' -PolicyAssignment $Assignment -Scope $($serviceprincipal.id) -ExemptionCategory   Waiver



  az policy assignment list --subscription aa2dc2da-846c-41ae-8fd5-26424f67c0d8 --output table


  
az policy assignment list --scope "$($group.id)" --output table

az policy assignment list --scope "$($serviceprincipal.id)" --output table
