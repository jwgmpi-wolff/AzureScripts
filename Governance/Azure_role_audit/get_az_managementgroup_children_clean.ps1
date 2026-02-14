
$ErrorActionPreference = 'continue'
# Connect to Azure (if not already connected)
Connect-AzAccount -Identity

$context = set-azcontext -Subscription wolffentpsub

# Specify the subscription ID
$contextsubscriptionid = "$($context.Subscription.id)"


$mgrouplist = ''
 
  $context = Connect-AzAccount     -identity
 
 set-azcontext -Tenant  $($context.Context.Tenant.TenantId)

$date = get-date
$Azrolesreport = ''





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

                [array]$mgrouplist += $mgmtgrpobj

    foreach ($child in $mginfo.Children) {
        if ($child.Type -ne '/subscriptions') {
            Get-ChildManagementGroups -mgmtGroup $child
        }
    }
}

# Main part of the script
$mgrouplist = New-Object System.Collections.Generic.List[object]


  $parentmgmgrp = 'Tenant Root Group'

 

$rootGroup = ((get-azmanagementgroup   | where displayname -eq $parentmgmgrp) ) # -split ('/') 


Get-ChildManagementGroups -mgmtGroup $rootGroup

$mgrouplist | where name | select -Unique name, parentname, child, type