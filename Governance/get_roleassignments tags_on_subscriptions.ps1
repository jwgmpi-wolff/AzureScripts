


connect-azaccount 

$subs = get-azsubscription 
$subowners = ''

foreach($sub in $subs) 
{
Set-AzContext -Subscription $($sub.name)  -Tenant $($sub.TenantId)

$subscriptionDetails = $sub

 

 $resourceobj = new-object PSObject 

 $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($subscriptionDetails.Id)" | Where-Object -filterscript {($_.RoleDefinitionName -eq "owner") -and ($_.Scope -match $subscriptionDetails.Id)}

 $roleAssignments | select RoleDefinitionName, DisplayName, Name,   ObjectType
 
                
foreach($roleassignment in $roleAssignments)
{
                    $resourceobj = new-object PSObject 
                    $resourceobj | Add-Member -MemberType NoteProperty -Name Subscription  -value $($sub.name) 
                    $resourceobj | add-member -membertype Noteproperty -name RoleDefinitionName -value $($roleassignment.RoleDefinitionName)
                    $resourceobj | add-member -membertype Noteproperty -name DisplayName -value $($roleassignment.DisplayName)
                    $resourceobj | add-member -membertype Noteproperty -name ObjectType -value $($roleassignment.ObjectType)
    ($sub.tags).GetEnumerator() | ForEach-Object {



                       #Write-Output "$($_.key)   = $($_.Value)" 
                     $resourceobj | add-member -membertype Noteproperty -name $($_.key) -value $($_.value)
                        [array]$subowners += $resourceobj
                      }
  
    }
}


$subowners








