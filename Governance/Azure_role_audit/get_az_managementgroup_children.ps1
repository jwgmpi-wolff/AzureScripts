# Connect to Azure (if not already connected)
Connect-AzAccount

$context = set-azcontext -Subscription wolffentpsub

# Specify the subscription ID
$contextsubscriptionid = "$($context.Subscription.id)"


$mgrouplist = ''
 
  $context = Connect-AzAccount     -identity
 
 set-azcontext -Tenant  $($context.Context.Tenant.TenantId)

$date = get-date
$Azrolesreport = ''

  


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
        if($($pmg.Type -ne '/subscriptions'))
        {
           $id = ((get-azmanagementgroup | where displayname -eq $($pmg.Name)).id) -split ('/') 
          $fullname = $($id)[-1]


          write-host " _______________" -foreground Cyan
          $id 
          $fullname
          write-host " _______________" -foreground darkcyan


              $mginfo = Get-AzManagementGroup  -Recurse -GroupName $($pmg.DisplayName) -Expand

             $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $($pmg.DisplayName) 
                $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($pmg.ParentName)
                $mgmtgrpobj | add-member -MemberType NoteProperty -name Child -value $($pmg.Displayname)
                $mgmtgrpobj | add-member -MemberType NoteProperty -name type -value $($pmg.type)

                [array]$mgrouplist += $mgmtgrpobj
        }
        else
        {


        
          write-host " _______________" -foreground Cyan
          $($pmg.Id)
           
          $($pmg.DisplayName)
          $($pmg.Type)

          write-host " _______________" -foreground darkcyan

            
               $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $($pmg.DisplayName) 
                 $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($pmg.ParentName)
                 $mgmtgrpobj | add-member -MemberType NoteProperty -name Type -value $($pmg.Type)
                 $mgmtgrpobj | add-member -MemberType NoteProperty -name Child -value $($pmg.Displayname)
           
                   [array]$mgrouplist += $mgmtgrpobj
        }
    }
}

 #$managementgroups =   Get-AzManagementGroup -Recurse -Groupname  $fullname -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children

  $a = 0
  foreach($mgmtgrpmember in $mgrouplist)  
 { 
                     $a = $a+1

                    # Determine the completion percentage
                    $ResourcesCompleted = ($a/$mgrouplist.count) * 100
                    $Resourceactivity = "Managementgroups  - Processing Iteration " + ($a + 1);
                    
             Write-Progress -Activity " $Resourceactivity " -Status "Progress:" -PercentComplete $ResourcesCompleted 
    
        foreach($childmgitem in (Get-AzManagementGroup -Recurse -Groupname  $($mgmtgrpmember.name) -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children))
        { 

             if($($childmgitem.Type -ne '/subscriptions'))
            {
                        $id = ((get-azmanagementgroup -groupname "$($childmgitem.displayname)").id -split('/'))
                         $fullname = $($id)[-1] 

                            $mginfo = Get-AzManagementGroup  -Recurse -GroupName $($childmgitem.DisplayName) -Expand

                  $mgmtgrpobj = new-object PSObject 
              
                    $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value  $($mginfo.Displayname)
                    $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($mginfo.ParentName)
                    $mgmtgrpobj | add-member -MemberType NoteProperty -name Type -value $($mginfo.Type)
                    $mgmtgrpobj | add-member -MemberType NoteProperty -name child -value $($mginfo.Children)
                    [array]$mgrouplist += $mgmtgrpobj
            }
          else
            {


        
              write-host " _______________" -foreground Cyan
              $($childmgitem.Id)
           
              $($childmgitem.DisplayName)
              $($childmgitem.Type)

              write-host " _______________" -foreground darkcyan

            
                   $mgmtgrpobj = new-object PSObject 
              
                    $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $($childmgitem.DisplayName) 
                     $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($childmgitem.ParentName)
                     $mgmtgrpobj | add-member -MemberType NoteProperty -name type -value $($childmgitem.type)
                     $mgmtgrpobj | add-member -MemberType NoteProperty -name Child -value $($childmgitem.Children)

                       [array]$mgrouplist += $mgmtgrpobj
            }

        $gchild = Get-AzManagementGroup -Recurse -GroupName $($childmgitem.DisplayName) -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children


            foreach($gchildmg in  $gchild)
            {
 
                 if($($gchildmg.Type -ne '/subscriptions'))
                {
          


                    $id = ((get-azmanagementgroup -groupname "$($gchildmg.name)").id -split('/'))
                     $fullname = $($id)[-1]
                        $mginfo = Get-AzManagementGroup  -Recurse -GroupName $($gchildmg.DisplayName) -Expand

                     $mgmtgrpobj = new-object PSObject 
              
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value  $($gchildmg.Displayname)
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($gchildmg.ParentName)
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name type -value $($gchildmg.type)
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name Child -value $($gchildmg.Children)


          

                [array]$mgrouplist += $mgmtgrpobj

                 }
                    else
                    {


        
                        write-host " _______________" -foreground Cyan
                        $($gchildmg.Id)
           
                        $($gchildmg.DisplayName)
                        $($gchildmg.Type)

                        write-host " _______________" -foreground darkcyan

            
                            $mgmtgrpobj = new-object PSObject 
              
                            $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $($gchildmg.DisplayName) 
                                $mgmtgrpobj | add-member -MemberType NoteProperty -name parentName -value $($gchildmg.ParentName)
                                $mgmtgrpobj | add-member -MemberType NoteProperty -name type -value $($gchildmg.type)
                                $mgmtgrpobj | add-member -MemberType NoteProperty -name Child -value $($gchildmg.Children)

                                [array]$mgrouplist += $mgmtgrpobj
                        }

        }
    }
}

  $mgrouplist |  where name  | select -Unique name, parentname, child, type

