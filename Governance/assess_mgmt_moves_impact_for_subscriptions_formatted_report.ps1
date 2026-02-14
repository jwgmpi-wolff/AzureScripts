# Connect to Azure (if not already connected)
Connect-AzAccount #-Identity

$context = set-azcontext -Subscription wolffentpsub

# Specify the subscription ID
$contextsubscriptionid = "$($context.Subscription.id)"

#####################################################
cls


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
 
  
            [array]$policyassignmentreports +=  $PolicyAssignmentobj  
            
  
}

$policyassignmentreports
 

  $currentroleslist = ''

# Check existing role assignments
Write-Host ""
Write-Host "Existing Role Assignments:"

$roleAssignments = Get-AzRoleAssignment -Scope "$($currentManagementGroup.ID)" -WarningAction SilentlyContinue
$roleAssignments | Format-Table -Property DisplayName, RoleDefinitionName, PrincipalName

    foreach($roleassignment in $roleAssignments)
    {

        $roleassignmentobj = new-object PSobject 
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleAssignmentName -value $($roleassignment.RoleAssignmentName)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleAssignmentId -value $($roleassignment.RoleAssignmentId)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name Scope -value $($roleassignment.Scope)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name DisplayName -value $($roleassignment.DisplayName)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name SignInName -value $($roleassignment.SignInName)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleDefinitionName -value $($roleassignment.RoleDefinitionName)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleDefinitionId -value $($roleassignment.RoleDefinitionId)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name ObjectId -value $($roleassignment.ObjectId)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name ObjectType -value $($roleassignment.ObjectType)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name CanDelegate -value $($roleassignment.CanDelegate)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name Description -value $($roleassignment.Description)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name ConditionVersion -value $($roleassignment.ConditionVersion)
         $roleassignmentobj | Add-Member -MemberType NoteProperty -Name Condition -value $($roleassignment.Condition)
 

         [array]$currentroleslist += $roleassignmentobj

                  
    }






# Check new policies assigned at the new management group level
Write-Host ""
Write-Host "New Policies Assigned at New Management Group Level:"

$newManagementGroupPolicies = Get-AzPolicyAssignment |where PolicyAssignmentId -like "$($targetManagementGroup.id)*"   -WarningAction SilentlyContinue
$newManagementGroupPolicies  

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

$inheritedRoleslist = ''

$inheritedRoles = Get-AzRoleAssignment -Scope "$($targetManagementGroup.id)" -WarningAction SilentlyContinue | Where-Object { $_.Scope -ne $($subscriptioninfo.Id) }
$inheritedRoles | Format-Table -Property DisplayName, RoleDefinitionName, PrincipalName



    foreach($inheritedRole in $inheritedRoles)
    {

        $inheritedroleassignmentobj = new-object PSobject 
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleAssignmentName -value $($inheritedRole.RoleAssignmentName)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleAssignmentId -value $($inheritedRole.RoleAssignmentId)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name Scope -value $($inheritedRole.Scope)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name DisplayName -value $($inheritedRole.DisplayName)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name SignInName -value $($inheritedRole.SignInName)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleDefinitionName -value $($inheritedRole.RoleDefinitionName)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name RoleDefinitionId -value $($inheritedRole.RoleDefinitionId)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name ObjectId -value $($inheritedRole.ObjectId)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name ObjectType -value $($inheritedRole.ObjectType)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name CanDelegate -value $($inheritedRole.CanDelegate)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name Description -value $($inheritedRole.Description)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name ConditionVersion -value $($inheritedRole.ConditionVersion)
         $inheritedroleassignmentobj | Add-Member -MemberType NoteProperty -Name Condition -value $($inheritedRole.Condition)
 

         [array]$inheritedRoleslist += $roleassignmentobj

                  
    }

  ##################################  
##  Move subscription um=ncomment if actual move is desired

# Additional checks related to quotas, resource locks, etc. can be added here

<# Move the subscription to the target management group
try {
    New-AzManagementGroupSubscription -GroupName $($targetManagementGroup.name)  -SubscriptionId $($subscriptioninfo.Id) -PassThru
    Write-Host "Subscription ,$($subscriptioninfo.Name), has been moved to the management group $($targetManagementGroup.name)."
} catch {
    Write-Error "Error moving subscription ,$($subscriptioninfo.Name),: $($_.Exception.Message)"
}
#>
 
############################################################################################################################################
# Report export section 


  ###GENERATE HTML Output for review        
 
    $CSS = @" 
  $title  $date
<Title> $title : $date </Title>
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


 
###############  current policies

 $title = 'Current Policies list'
   ###GENERATE HTML Output for review        
 
    $CSS = @" 
  $title  $date
<Title> $title : $date </Title>
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


 ($policyassignmentreports| SELECT  -unique Identity,`
  Location,`
   Name,`
    ResourceId,`
     ResourceName,`
      ResourceType,`
       PolicyAssignmentId  | `
ConvertTo-Html -Head $CSS ) | out-file "C:\TEMP\Impact_for_move_on_$($currentManagementGroup.name)_$($targetManagementGroup.name).html"
#Invoke-Item    "C:\TEMP\Impact_for_move_on_$($currentManagementGroup.name).html"                                                                                                     


######## Prep for export to storage account

$resultsfilename1 = "Impact_for_move_on_$($currentManagementGroup.name)_policies.csv"

$rolesauditreport =  $Azrolesreport| SELECT -unique Identity,`
  Location,`
   Name,`
    ResourceId,`
     ResourceName,`
      ResourceType,`
       PolicyAssignmentIde | export-csv  $resultsfilename1  -notypeinformation




 ##### storage sub info and creation

##############################################################################

# roles assignments

###############  current roles

 $title = 'Current roles assigned list'
   ###GENERATE HTML Output for review        
 
    $CSS = @" 
  $title  $date
<Title> $title : $date </Title>
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


 ($currentroleslist | SELECT  -unique  RoleAssignmentName,`
  RoleAssignmentId,`
   Scope,`
    DisplayName,`
      SignInName,`
       RoleDefinitionName,`
         RoleDefinitionId,`
          ObjectId,`
           ObjectType,`
            CanDelegate,`
              Description,`
               ConditionVersion,`
                 Condition | `
ConvertTo-Html -Head $CSS ) | out-file "C:\TEMP\Impact_for_move_on_$($currentManagementGroup.name)_$($targetManagementGroup.name).html" -append
#Invoke-Item   "C:\TEMP\Impact_for_move_on_$($currentManagementGroup.name).html"                                                                                                    


#########################
## 
$resultsfilename2 = "Impact_for_move_on_$($currentManagementGroup.name)_roles.csv"

  $newpolicyassignmentreports| SELECT  -unique  RoleAssignmentName,`
  RoleAssignmentId,`
   Scope,`
    DisplayName,`
      SignInName,`
       RoleDefinitionName,`
         RoleDefinitionId,`
          ObjectId,`
           ObjectType,`
            CanDelegate,`
              Description,`
               ConditionVersion,`
                 Condition | export-csv $resultsfilename2 -NoTypeInformation 



###############################################################################################################

###############  inherited policies

 $title = 'inherited Policies list'
   ###GENERATE HTML Output for review        
 
    $CSS = @" 
  $title  $date
<Title> $title : $date </Title>
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


 ($policyassignmentreports| SELECT -unique Identity,`
  Location,`
   Name,`
    ResourceId,`
     ResourceName,`
      ResourceType,`
       PolicyAssignmentId  | `
ConvertTo-Html -Head $CSS ) | out-file "C:\TEMP\Impact_for_move_on_$($currentManagementGroup.name)_$($targetManagementGroup.name).html" -Append
                                                                                                 


######## Prep for export to storage account

$resultsfilename3 = "Impact_for_move_on_$($targetManagementGroup.name)_policies.csv"

$inheritedreport =  $policyassignmentreports| SELECT -unique Identity,`
  Location,`
   Name,`
    ResourceId,`
     ResourceName,`
      ResourceType,`
       PolicyAssignmentId | export-csv  $resultsfilename3  -notypeinformation




 ##### storage sub info and creation

##############################################################################

# Role assignments

###############  current policies

 $title = 'inherited roles assignments list '
   ###GENERATE HTML Output for review        
 
    $CSS = @" 
  $title  $date
<Title> $title : $date </Title>
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


 ($inheritedRoleslist| SELECT  -Unique  RoleAssignmentName,`
  RoleAssignmentId,`
   Scope,`
    DisplayName,`
      SignInName,`
       RoleDefinitionName,`
        RoleDefinitionId,`
          ObjectId,`
           ObjectType,`
            CanDelegate,`
              Description,`
               ConditionVersion,`
                 Condition | `
ConvertTo-Html -Head $CSS ) | out-file "C:\TEMP\Impact_for_move_on_$($currentManagementGroup.name)_$($targetManagementGroup.name).html" -append
 Invoke-Item    "C:\TEMP\Impact_for_move_on_$($currentManagementGroup.name)_$($targetManagementGroup.name).html"                                                                        


 ############  Assignment list to storeage
 $resultsfilename4 = "Impact_for_move_on_$($targetManagementGroup.name)_roles.csv"

  $inheritedRoleslist| SELECT -Unique   RoleAssignmentName,`
  RoleAssignmentId,`
   Scope,`
    DisplayName,`
      SignInName,`
       RoleDefinitionName,`
        RoleDefinitionId,`
          ObjectId,`
           ObjectType,`
            CanDelegate,`
              Description,`
               ConditionVersion,`
                 Condition | export-csv $resultsfilename4 -NoTypeInformation 


###############################################################################

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
$storagecontainer = 'managementgroupmigrationreports'   ### Container for export


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
       

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename1  -File $resultsfilename1 -Context $destContext -Force

         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename2  -File $resultsfilename2 -Context $destContext -Force
         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename3  -File $resultsfilename3 -Context $destContext -Force
         Set-azStorageBlobContent -Container $storagecontainer -Blob $resultsfilename4  -File $resultsfilename4 -Context $destContext -Force




 

















