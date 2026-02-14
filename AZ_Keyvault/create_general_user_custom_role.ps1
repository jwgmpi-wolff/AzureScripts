 
 Connect-AzAccount -Identity

 set-azcontext -Subscription wolffentpsub2

$sub =  get-azsubscription -SubscriptionName wolffentpsub2

$role = New-Object -TypeName Microsoft.Azure.Commands.Resources.Models.Authorization.PSRoleDefinition
$role.Name = 'GeneralUSersub2'
$role.Description = 'Can monitor, start, and restart virtual machines.'
$role.IsCustom = $true
$role.AssignableScopes = @("/subscriptions/$($sub.id)")


$role.Actions = @(
    "*/read",
    "*/action",
    "Microsoft.Resources/subscriptions/read",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Management/managementGroups/read"
)


$role.NotActions = @(
    "Microsoft.Authorization/*/write",
    "Microsoft.Authorization/*/delete",
    "Microsoft.Blueprint/*",
    "Microsoft.Security/*/write",
    "Microsoft.Security/*/delete",
    "Microsoft.PolicyInsights/*/write",
    "Microsoft.PolicyInsights/*/delete",
    "Microsoft.Management/*/write",
    "Microsoft.Management/*/delete"
)



$roleinfo = get-azroledefinition   -Name  GeneralUSersub2 -Verbose
remove-AzRoleDefinition  -id $($roleinfo.id) -Verbose -force
New-AzRoleDefinition -Role $role -Verbose


 