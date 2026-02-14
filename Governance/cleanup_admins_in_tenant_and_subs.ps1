 ############  Need to cascade to lower levels of management group 
####install-module microsoft.graph.Devices.CorporateManagement -MinimumVersion 2.9.0 -AllowClobber
##install-module microsoft.graph
# Import required modules

$MaximumFunctionCount = 16384
$MaximumVariableCount = 16384
 #Import-Module Az   -force   
Import-Module -Name AzureAD  
Import-Module Az.Accounts   -force   -ErrorAction Ignore
Import-Module Az.Resources   -force    -ErrorAction Ignore
import-module microsoft.graph -force   -ErrorAction Ignore
import-module Microsoft.Graph.Devices.CorporateManagement   -force  -ErrorAction Ignore

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'

###########################
 $ErrorActionPreference = 'silentlycontinue'


 $mgrouplist = ''
 
  $context = Connect-AzAccount     -identity
 
 $azadcontext = connect-azuread 

 set-azcontext -Tenant  $($context.Context.Tenant.TenantId)

$date = get-date
$Azrolesreport = ''

  
$cleanupname   = "jwgmpi@wolffentp.org"

 #### On line  ($parentmgmgrp = 'AdminMG') 
 # replace <AdminMG> with the management group name to filter subscriptions on

  $parentmgmgrp = 'Tenant Root Group'

  $id = ((get-azmanagementgroup   | where displayname -eq $parentmgmgrp).id) -split ('/') 
  #$id = ((get-azmanagementgroup  | where displayname -eq 'secadminmg').id) -split ('/') 
 
 

  $fullname = $($id)[-1]

     $mginfo = Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand   

                $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $fullname
                $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value   "$fullname - Top Parent"

                   [array]$mgrouplist += $mgmtgrpobj
 

   foreach($pmg in (Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand -WarningAction SilentlyContinue  | Select-Object -ExpandProperty Children))
   {
    if($pmg)
    {
           $id = ((get-azmanagementgroup -ErrorAction Ignore | where displayname -eq $($pmg.Name)).id) -split ('/') 
          $fullname = $($id)[-1]


          write-host " _______________" -foreground Cyan
          $id 
          $fullname
          write-host " _______________" -foreground darkcyan


              $mginfo = Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand

             $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $fullname 
                 $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($mginfo.ParentName)

                [array]$mgrouplist += $mgmtgrpobj
        }
}

 #$managementgroups =   Get-AzManagementGroup -Recurse -Groupname  $fullname -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children

  $a = 0
  foreach($mgmtgrpmember in ($mgrouplist |  where name   ))  
 { 
                     $a = $a+1

                    # Determine the completion percentage
                    $ResourcesCompleted = ($a/$mgrouplist.count) * 100
                    $Resourceactivity = "Managementgroups  - Processing Iteration " + ($a + 1);
                    
             Write-Progress -Activity " $Resourceactivity " -Status "Progress:" -PercentComplete $ResourcesCompleted 
    
        foreach($childmgitem in (Get-AzManagementGroup -Recurse -Groupname  $($mgmtgrpmember.Name) -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children))
        { 
                    $id = ((get-azmanagementgroup -groupname "$($childmgitem.name)").id -split('/'))
                     $fullname = $($id)[-1] 

                        $mginfo = Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand

              $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value  $fullname
                $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($mginfo.ParentName)

                [array]$mgrouplist += $mgmtgrpobj
        

        $gchild = Get-AzManagementGroup -Recurse -GroupName $fullname -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children


            foreach($gchildmg in  $gchild)
            {
 
                    $id = ((get-azmanagementgroup -groupname "$($gchildmg.name)").id -split('/'))
                     $fullname = $($id)[-1]
                        $mginfo = Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand

                     $mgmtgrpobj = new-object PSObject 
              
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value  $fullname
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($mginfo.ParentName)
          

                [array]$mgrouplist += $mgmtgrpobj

              }
        }
 }

  $mgrouplist |  where name  | select -Unique name, parentname




 foreach($mgroup in ($mgrouplist | where name)  )
 {
   $b= 0

        if((get-azmanagementgroup -Expand $($mgroup.name)).Children | where type -EQ '/subscriptions')
        {
                             $b = $b+1

                    # Determine the completion percentage
                    $subResourcesCompleted = ($b/$($mgrouplist.name).count) * 100
                    $subResourceactivity = "Subscriptions  - Processing Iteration " + ($b + 1);
                     Write-Progress -Activity " $subResourceactivity " -Status "Progress:" -PercentComplete $subResourcesCompleted 
    

                $subscriptionslists =   (get-azmanagementgroup -Expand $($mgroup.name)).Children  | where type -eq '/subscriptions'
                $i = 0
                 write-host " $($mgroup) - $($subscriptionslists.DisplayName)" -BackgroundColor Yellow
        
                foreach($sub in $subscriptionslists) 
                {
    
                    $subscriptionName = $($sub.DisplayName)
                    $token = Get-AzAccessToken -Tenant  $($context.Context.Tenant.TenantId)
                    set-azcontext -subscription $subscriptionname -erroraction ignore


  
                        $i = $i +1
                        write-host " $($sub.DisplayName)  - $($subscriptions.count -$i)" -ForegroundColor Green

                        $allassignments = Get-AzRoleAssignment -Scope "$($sub.id)"  
 
                        foreach($assignment in $allassignments)
                        {
                            if($($assignment.Scope) -eq "$($sub.id)" )
                            {
                                $inheritancesource = "made directly on the resource $($resource.Name)"
                                $inheritance = 'no direct assignment'
                                write-host "$inheritance" -ForegroundColor cyan
                            }
                            else
                            {
                                $inheritancesource = "inherited from scope $($assignment.Scope)"
                                $inheritance = 'yes'
                            }
                            try  
                                {  
                                    # Attempt to get the user  
                                    $user = Get-AzADUser -ObjectId $($assignment.objectid)  -erroraction ignore
  
                                    if($user -ne $null)  
                                    {  
                                        # Print the user, resource, and role details  
                                      #  Write-Output "User: $($user.DisplayName) Resource: $($resource.Name) Role: $($roleDefinition.Name) Role Description: $($roleDefinition.Description)"  
                                        $username = $($user.DisplayName)
                                    }  
                                }  
                                catch  
                                {  
                                    # If the user retrieval failed, it might be a group  
                                    try  
                                    {  
                                        # Attempt to get the group  
                                        $group = Get-AzADGroup -ObjectId $objectId  
  
                                        if($group -ne $null)  
                                        {  
                                            # Print the group, resource, and role details  
                                           # Write-Output "Group: $($group.DisplayName) Resource: $($resource.Name) Role: $($roleDefinition.Name) Role Description: $($roleDefinition.Description)"  
                                            $groupname = $($group.DisplayName)
                                        }  
                                    }  
                                    catch  
                                    {  
                                        # If the group retrieval also failed, it might be a service principal or something else  
                                        #Write-Output "Unrecognized ObjectId: $objectId Resource: $($resource.Name) Role: $($roleDefinition.Name) Role Description: $($roleDefinition.Description)" 
                                        $groupname = 'none' 
                                    }  
                                } 




                            $roleobj = new-object PSObject 

                            $roleobj | Add-Member -MemberType NoteProperty -name Managementgroup -value $($mgroup.name) 
                            $roleobj | Add-Member -MemberType NoteProperty -name RoleAssignmentName -value $($assignment.DisplayName)
                            $roleobj | Add-Member -MemberType NoteProperty -name RoleAssignmentID -value $($assignment.RoleAssignmentId)
                            $roleobj | Add-Member -MemberType NoteProperty -name inheritance -value $inheritance
                            $roleobj | Add-Member -MemberType NoteProperty -name user -value $username
                            $roleobj | Add-Member -MemberType NoteProperty -name Group -value $groupname
                            $roleobj | Add-Member -MemberType NoteProperty -name inheritancesource -value $inheritancesource
                            $roleobj | Add-Member -MemberType NoteProperty -name DisplayName -value $($assignment.DisplayName)
                            $roleobj | Add-Member -MemberType NoteProperty -name SignInName -value $($assignment.SignInName)
                            $roleobj | Add-Member -MemberType NoteProperty -name RoleDefinitionName -value $($assignment.RoleDefinitionName)
                            $roleobj | Add-Member -MemberType NoteProperty -name Subscriptionname -value $($sub.displayname)
                            $roleobj | Add-Member -MemberType NoteProperty -name Subscriptionid -value $($sub.Id)
                            $roleobj | Add-Member -MemberType NoteProperty -name ObjectType -value $($assignment.ObjectType)
                            $roleobj | Add-Member -MemberType NoteProperty -name CanDelegate -value $($assignment.CanDelegate)
                            $roleobj | Add-Member -MemberType NoteProperty -name Scope -value $($assignment.Scope)
                            $roleobj | Add-Member -MemberType NoteProperty -name Parentname -value $($mgroup.parentName)
  
                             [array]$Azrolesreport += $roleobj

                        }   
                    
                }

               
        }
        
   }




 ###GENERATE HTML Output for review        
 
    $CSS = @" 
  Azure Role Audit $date
<Title> Azure Role Audit $date Report: $date </Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	border-top: 1px solid #4B0082;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #4B0082;
	border-bottom: 1px solid #4B0082;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #4B0082;
}
</Style>
"@


 

 

 (((($Azrolesreport | where-object {$($_.SignInName) -and  $($_.Roledefinitionname) -like '* administrator*'}  )| SELECT Managementgroup `
      ,RoleAssignmentName `
      ,RoleAssignmentID `
      ,inheritance `
      ,inheritancesource `
      ,displayname `
      ,SignInName `
      ,RoleDefinitionName `
      ,Subscriptionname `
      ,Subscriptionid `
      ,ObjectType `
      ,CanDelegate `
      ,Scope `
      ,Parentname | `
ConvertTo-Html -Head $CSS ).replace("Administrator","<font color=red>Administrator</font>")).replace("subscriptions","<font color=green>subscriptions</font>"))| out-file "C:\TEMP\azure_sub_role_audit.html"
Invoke-Item    "C:\TEMP\azure_sub_role_audit.html"    



$user = Get-azaduser -UserPrincipalName $cleanupname

 

foreach ($Azrole in ($Azrolesreport | where-object {$($_.SignInName) -eq $cleanupname -and  $($_.Roledefinitionname) -like '* administrator*'}  ) )
{

        Write-Host "$($azrole.RoleAssignmentName) - $($azrole.SignInName) " -ForegroundColor cyan  

        $role = get-AzureADDirectoryRole | where displayname  -eq  $($azrole.RoleDefinitionName)

  
    
     Remove-AzRoleAssignment -SignInName $cleanupname -RoleDefinitionName "$($azrole.RoleDefinitionName)"  -Scope "$($azrole.Scope)"   -verbose


 }






     