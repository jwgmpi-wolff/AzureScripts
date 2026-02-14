#Requires -Version 5.1

###########################
 $ErrorActionPreference = 'continue'


 $mgrouplist = ''

 $mgsubschildren =''
 
  $context = Connect-AzAccount     -identity
 
 set-azcontext -Tenant  $($context.Context.Tenant.TenantId)

$date = get-date
 

  $mgsubschildren


 #### On line  ($parentmgmgrp = 'AdminMG') 
 # replace <AdminMG> with the management group name to filter subscriptions on

  $parentmgmgrp = 'Tenant Root Group'

  $id = (((get-azmanagementgroup   | where displayname -eq $parentmgmgrp).id) -split ('/')) -replace('}','')
  #$id = ((get-azmanagementgroup  | where displayname -eq 'secadminmg').id) -split ('/') 
 
 

  $fullname = $($id)[-1]

     $mginfo = Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand   
     

                $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $fullname
                $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value   "$fullname - Top Parent"
                $mgmtgrpobj | add-member -MemberType NoteProperty -name Type -value  $($mginfo.Type)  

                   [array]$mgrouplist += $mgmtgrpobj

 
 $pmgchildren =  (Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand -WarningAction SilentlyContinue) | where type -notlike '*subscriptions*' | Select-Object -ExpandProperty Children

  
  

   foreach($pmg in ($pmgchildren | where type -ne '/subscriptions') )
   {
    if($pmg)
    {
            If ($($pmg.type) -notlike "*subscription*")
            {
                   $id = (((get-azmanagementgroup | where displayname -eq $($pmg.Name) | select id) -split ('/') ) -replace('}','')) -replace('{',"")
                   #$id
                  $fullname = $($id)[-1]


                  write-host " _______________" -foreground Cyan
                   $id 
                  $fullname
                  write-host " _______________" -foreground darkcyan

                    
                      $mginfo = Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand -ErrorAction SilentlyContinue

                     $mgmtgrpobj = new-object PSObject 
              
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $fullname 
                         $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($mginfo.ParentName)

                        [array]$mgrouplist += $mgmtgrpobj
            }
    }

}

 #$managementgroups =   Get-AzManagementGroup -Recurse -Groupname  $fullname -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children

  $a = 0
  foreach($mgmtgrpmember in ($mgrouplist |  where name -ne $null  ))  
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


            foreach($gchildmg in  ($gchild |  where name -ne $null))
            {
 
                    $id = ((get-azmanagementgroup -groupname "$($gchildmg.name)").id -split('/'))
                     $id 
                     $fullname = $($id)[-1]
                     try{
                        $mginfo = Get-AzManagementGroup  -Recurse -GroupName $fullname -Expand -ErrorAction silentlycontinue
                        }
                        Catch
                        {
                            Write-Host " no fullname for $($id) " -ForegroundColor Red

                        }

                     $mgmtgrpobj = new-object PSObject 
              
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value  $fullname
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($mginfo.ParentName)
          

                [array]$mgrouplist += $mgmtgrpobj

              }
        }
 }

  $mgrouplist |  where name  | select -Unique name, parentname




 foreach($mgroup in $mgrouplist  | where name -ne $null  )
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
                
                 write-host " processing $($mgroup.name) MG - $($subscriptionslists.DisplayName)" -ForegroundColor Cyan


                 foreach($sub in $subscriptionslists)
                 {
                 $subobj = new-object PSOBject 


                 $subobj | Add-Member -MemberType NoteProperty -Name Mgroup -Value $($mgroup.name)
                 $subobj | Add-Member -MemberType NoteProperty -Name parentname -Value $($mgroup.parentname)
                 $subobj | Add-Member -MemberType NoteProperty -Name Subscriptionname -Value $($sub.DisplayName)
                 [array]$mgsubschildren += $subobj

                 }

        }
 }


 $mgsubschildren | select mgroup, parentname, Subscriptionname -Unique












