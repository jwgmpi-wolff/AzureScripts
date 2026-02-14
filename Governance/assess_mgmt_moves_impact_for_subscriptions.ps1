# Connect to Azure (if not already connected)
Connect-AzAccount #-Identity

$context = set-azcontext -Subscription wolffentpsub

# Specify the subscription ID
$contextsubscriptionid = "$($context.Subscription.id)"

#####################################################

 $mgrouplist = ''
  

# Method to handle recursion
function Get-ChildManagementGroups ($mgmtGroup) {
$mgmtGroup

    $id = ((Get-AzManagementGroup -GroupName $mgmtGroup.Name).Id )   -split ('/')
    $fullname = $($id)[-1]

    $mginfo = Get-AzManagementGroup -Recurse -GroupName $fullname -Expand

                $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $($mginfo.DisplayName) 
                $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($mginfo.ParentName)
                $mgmtgrpobj | add-member -MemberType NoteProperty -name Child -value $($mginfo.Displayname)
                $mgmtgrpobj | add-member -MemberType NoteProperty -name type -value $($mginfo.type)
                $mgmtgrpobj | add-member -MemberType NoteProperty -name ID -value $($mginfo.ID)

                [array]$mgrouplist += $mgmtgrpobj

    foreach ($child in $mginfo.Children) {
        if ($child.Type -ne '/subscriptions') {
            Get-ChildManagementGroups -mgmtGroup $child
        }
    }
    return [array]$mgrouplist
}

 

  $parentmgmgrp = 'Tenant Root Group'

 

$rootGroup = ((get-azmanagementgroup   | where displayname -eq $parentmgmgrp) ) # -split ('/') 


$mgrouplist = Get-ChildManagementGroups -mgmtGroup $rootGroup

$mgrouplist | where-object {$_.parentname -ne $null  -or $_.name -eq 'Tenant Root Group' } |  select -Unique name, parentname, child, type

 

 ################################################

# Prompt user for current management group
$currentManagementGroup =  $mgrouplist | Select name, parentname, type, child, ID | where-object {$_.parentname -ne $null  -or $_.name -eq 'Tenant Root Group' } | ogv -title " select source management group:" -PassThru | Select name, parentname, type, child, ID

$mgsubs = (Get-AzManagementGroup  -Recurse -GroupName $($currentManagementGroup.name)  -Expand -WarningAction SilentlyContinue  | Select-Object -ExpandProperty Children) | where type -eq '/subscriptions'



$subscription = $mgsubs | Select name, type, ID, Displayname   | ogv -title "select subscription to move:" -passthru | Select name, type, ID, Displayname




# Prompt user for target management group
$targetManagementGroup = $mgrouplist | Select name, parentname, type, child, ID  |  where-object {$_.parentname -ne $null  -or $_.name -eq 'Tenant Root Group' -and  $_.name  -ne $($currentManagementGroup.name) }| ogv -title " select Destination management group:" -PassThru | select   name, parentname, type, child , ID

# Get the subscription details
#$subscription = Get-AzSubscription -SubscriptionId $subscriptionId




$subscriptioninfo = get-azsubscription  -SubscriptionName $($subscription.DisplayName)




 #####
 
# List the management group hierarchy for the subscription

#$managementGroups = Get-AzManagementGroup -Recurse -GroupName ($currentManagementGroup.DisplayName) -Expand -WarningAction SilentlyContinue |
 #   Select-Object -ExpandProperty Children |
 #   Select-Object Name, Id, @{Name="ManagementGroup"; Expression={$_.properties.managementGroupAncestorsChain.displayname}}

 

# Display the results
Write-Host "Subscription Details:"
Write-Host "Subscription Name: $($subscriptioninfo.Name)"
Write-Host "Subscription ID: $($subscriptioninfo.Id)"
Write-Host ""

#Write-Host "Management Group Hierarchy:"
#$managementGroups | Format-Table -AutoSize

# Check policies assigned at the management group level
Write-Host ""
Write-Host "Policies Assigned at Management Group Level: $($currentManagementGroup.name)"

$managementGroupPolicies = Get-AzPolicyAssignment  -Scope "/providers/Microsoft.Management/managementgroups/$($currentManagementGroup.name)" -WarningAction SilentlyContinue
$policyassignmentreports = ''

foreach($currentpolicy in $managementGroupPolicies)
{
          
            $PolicyAssignmentobj = New-Object PSObject 

            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  Identity   -value $($currentpolicy.Identity)  
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  Location   -value $($currentpolicy.Location)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  Name   -value $($currentpolicy.Name)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  ResourceId   -value $($currentpolicy.ResourceId)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  ResourceName   -value $($currentpolicy.ResourceName)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  ResourceType   -value $($currentpolicy.ResourceType)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  PolicyAssignmentId   -value $($currentpolicy.PolicyAssignmentId)
 
  
            [array]$policyassignmentreports +=    $PolicyAssignmentobj  
            
  
}

$policyassignmentreports


  

# Check existing role assignments
Write-Host ""
Write-Host "Existing Role Assignments:"

$roleAssignments = Get-AzRoleAssignment -Scope "$($currentManagementGroup.ID)" -WarningAction SilentlyContinue
$roleAssignments | Format-Table -Property DisplayName, RoleDefinitionName, PrincipalName

# Check new policies assigned at the new management group level
Write-Host ""
Write-Host "New Policies Assigned at New Management Group Level:"

$newManagementGroupPolicies = Get-AzPolicyAssignment |where PolicyAssignmentId -like "$($targetManagementGroup.id)*"   -WarningAction SilentlyContinue
$newManagementGroupPolicies #| Where-Object { $_.Scope -ne $($subscriptioninfo.Id) } | Format-Table -Property DisplayName, PolicyDefinitionName

$newManagementGroupPolicies = Get-AzPolicyAssignment  -Scope "/providers/Microsoft.Management/managementgroups/$($targetManagementGroup.name)" -WarningAction SilentlyContinue
$newpolicyassignmentreports = ''

foreach($newpolicy in $newManagementGroupPolicies)
{
          
            $PolicyAssignmentobj = New-Object PSObject 

            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  Identity   -value $($newpolicy.Identity)  
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  Location   -value $($newpolicy.Location)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  Name   -value $($newpolicy.Name)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  ResourceId   -value $($newpolicy.ResourceId)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  ResourceName   -value $($newpolicy.ResourceName)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  ResourceType   -value $($newpolicy.ResourceType)
            $PolicyAssignmentobj | Add-Member -MemberType NoteProperty -Name  PolicyAssignmentId   -value $($newpolicy.PolicyAssignmentId)
 
  
            [array]$newpolicyassignmentreports +=    $PolicyAssignmentobj  
            
  
}

$newpolicyassignmentreports







# Check inherited roles from the new parent management group
Write-Host ""
Write-Host "Inherited Roles from New Parent Management Group:"

$inheritedRoles = Get-AzRoleAssignment -Scope "$($targetManagementGroup.id)" -WarningAction SilentlyContinue | Where-Object { $_.Scope -ne $($subscriptioninfo.Id) }
$inheritedRoles | Format-Table -Property DisplayName, RoleDefinitionName, PrincipalName

# Additional checks related to quotas, resource locks, etc. can be added here

# Move the subscription to the target management group
try {
    New-AzManagementGroupSubscription -GroupName $($targetManagementGroup.name)  -SubscriptionId $($subscriptioninfo.Id) -PassThru
    Write-Host "Subscription ,$($subscriptioninfo.Name), has been moved to the management group $($targetManagementGroup.name)."
} catch {
    Write-Error "Error moving subscription ,$($subscriptioninfo.Name),: $($_.Exception.Message)"
}

 














