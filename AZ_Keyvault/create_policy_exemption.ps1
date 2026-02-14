Connect-azaccount -Identity
  

set-azcontext -Subscription wolffsecsub



$ManagementGroup = Get-AzManagementGroup -GroupName 'secadminmg'
$Assignment = Get-AzPolicyAssignment  | where displayname -eq 'create_resource_block_with_exclusions' | select -First 1
New-AzPolicyExemption -Name 'Adminsallowedcreate' -PolicyAssignment $Assignment -Scope $ManagementGroup.Id -ExemptionCategory   Waiver




  az policy assignment list --subscription aa2dc2da-846c-41ae-8fd5-26424f67c0d8 --output table

az policy assignment list --scope "/providers/Microsoft.Management/managementGroups/secadminmg" --output table
