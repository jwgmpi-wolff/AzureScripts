<# 

.NOTES

    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 

    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 

    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 

    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all

    implied warranties including, without limitation, any implied warranties of merchantability

    or of fitness for a particular purpose. The entire risk arising out of the use or performance

    of the sample and documentation remains with you. In no event shall Microsoft, its authors,

    or anyone else involved in the creation, production, or delivery of the script be liable for 

    any damages whatsoever (including, without limitation, damages for loss of business profits, 

    business interruption, loss of business information, or other pecuniary loss) arising out of 

    the use of or inability to use the sample or documentation, even if Microsoft has been advised 

    of the possibility of such damages, rising out of the use of or inability to use the sample script, 

    even if Microsoft has been advised of the possibility of such damages.

    Scriptname: get_user_role_access_at subscription.ps1
    Description:  Script to collect all Azure Role assignment and identify scope and if the role is inhertied  
                   
                  Script will generate report and html report and output in CSV to a storage account
          

    Purpose:  Audit of Assigned assigned roles on subscriptions and scope in a tenant

   Requires role Management Group Reader  

#> 

 ############  Need to cascade to lower levels of management group 
####install-module microsoft.graph.Devices.CorporateManagement -MinimumVersion 2.9.0 -AllowClobber
##install-module microsoft.graph
# Import required modules

#Import-Module Az   -force   
  
Import-Module Az.Accounts   -force   -ErrorAction Ignore
Import-Module Az.Resources   -force    -ErrorAction Ignore
import-module microsoft.graph -force   -ErrorAction Ignore
import-module Microsoft.Graph.Devices.CorporateManagement   -force  -ErrorAction Ignore

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'

###########################
 
$MaximumFunctionCount = 16384
$MaximumVariableCount = 16384

 $mgrouplist = ''
 
  $context = Connect-AzAccount     -identity
 
 set-azcontext -Tenant  $($context.Context.Tenant.TenantId)

$date = get-date
$Azrolesreport = ''

 


 #### On line  ($parentmgmgrp = 'AdminMG') 
 # replace <AdminMG> with the management group name to filter subscriptions on

 #$parentmgmgrp = 'AdminMG'

  $id = ((get-azmanagementgroup  | where displayname -eq 'Tenant Root Group').id) -split ('/') 
  $fullname = $($id)[-1]
   
   foreach($pmg in (Get-AzManagementGroup -Recurse -GroupName $fullname -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children))
   {

           $id = ((get-azmanagementgroup | where displayname -eq $($pmg.Name)).id) -split ('/') 
          $fullname = $($id)[-1]


             $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value   $fullname 

                [array]$mgrouplist += $mgmtgrpobj
}

 #$managementgroups =   Get-AzManagementGroup -Recurse -Groupname  $fullname -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children

  
  foreach($mgmtgrpmember in $mgrouplist)
 { 
 

    
        foreach($childmgitem in (Get-AzManagementGroup -Recurse -Groupname  $($mgmtgrpmember.Name) -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children))
        { 
                    $id = ((get-azmanagementgroup -groupname "$($childmgitem.name)").id -split('/'))
                     $fullname = $($id)[-1] 

              $mgmtgrpobj = new-object PSObject 
              
                $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value  $fullname

                [array]$mgrouplist += $mgmtgrpobj
        

        $gchild = Get-AzManagementGroup -Recurse -GroupName $fullname -Expand -WarningAction SilentlyContinue | Select-Object -ExpandProperty Children


            foreach($gchildmg in  $gchild)
            {
 
                    $id = ((get-azmanagementgroup -groupname "$($gchildmg.name)").id -split('/'))
                     $fullname = $($id)[-1]

                     $mgmtgrpobj = new-object PSObject 
              
                        $mgmtgrpobj | add-member -MemberType NoteProperty -name name -value  $fullname
            

                [array]$mgrouplist += $mgmtgrpobj

              }
        }
 }

  $mgrouplist | Where-Object {$_ -ne '' -or $_ -ne $null} | select -Unique name




 foreach($mgroup in $($mgrouplist.name) )
 {
        

        $subscriptionslists =   (get-azmanagementgroup -Expand $($mgroup)).Children  | where type -EQ '/subscriptions'
        $i = 0
         

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

                    $roleobj | Add-Member -MemberType NoteProperty -name Managementgroup -value $($mgroup) 
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

  
         

                    [array]$Azrolesreport += $roleobj
                    
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


 

 

 ((($Azrolesreport| SELECT Managementgroup `
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
      ,Scope  | `
ConvertTo-Html -Head $CSS ).replace("root","<font color=red>root</font>")).replace("subscriptions","<font color=green>subscriptions</font>"))| out-file "C:\TEMP\azure_sub_role_audit.html"
Invoke-Item    "C:\TEMP\azure_sub_role_audit.html"                                                                                                     


######## Prep for export to storage account

$resultsfilename = 'rolessubauditreport.csv'

$rolesauditreport =  $Azrolesreport| SELECT Managementgroup  `
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
      ,Scope  | export-csv  $resultsfilename  -notypeinformation




 ##### storage sub info and creation

#connect-azaccount ## only uncomment if using a storage account under another tenant or account for consilidation of reports 


 ########################################################################################################################
 ###

 #### Change subscription , Region, Resourcegroupname, Storageaccountname below 

$Region =  "West US"   ## pick storage account region 

 $subscriptionselected = 'wolffentpSub'   ### designated storage account subscription if different from current running subscription



$resourcegroupname = 'wolffautomationrg'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolffautosa'    ## dedicate storage account
$storagecontainer = 'rolesaudit'   ### Container for export


### end storagesub info

set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)

 

#BEGIN Create Storage Accounts
 
 
 
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $resourcegroupname -Name $storageaccountname ))
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount -ResourceGroupName $resourcegroupname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose
 
     
        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $resourcegroupname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
        $StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
        $destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
                                        -StorageAccountKey $StorageKey


             #Upload  .csv to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext
                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename  -File $resultsfilename -Context $destContext -Force


 
