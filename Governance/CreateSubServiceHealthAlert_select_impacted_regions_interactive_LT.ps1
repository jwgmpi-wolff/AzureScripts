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

Purpose:



This PowerShell script is designed to streamline Azure administration by importing 
essential modules for Azure, Microsoft Graph, Azure AD, and Azure Monitor operations. 
It sets high limits for functions and variables to handle extensive operations. 
The GETAZSUBS function retrieves all Azure subscriptions, displaying them to the 
user for selection. Users can choose one or more subscriptions, which are then 
stored for further processing. The script also defines roles (Owner, Contributor) 
to be added to an action group for receiving service health alerts, with an option 
to exclude specific groups. A random number is generated for rule uniqueness. 
The NEWRGCREATE function lists available Azure locations, prompting the user 
to select a location and provide a name for a new resource group. 
This function then creates the resource group based on the user’s input. 
Overall, the script enhances efficiency and user-friendliness in managing 
Azure subscriptions, roles, and resource groups.


 

import-module az | out-null
import-module microsoft.graph -force | out-null
import-module azuread -force  | out-null
import-module az.monitor -force   | out-null
 #> 
$MaximumFunctionCount = 16384
$MaximumVariableCount = 16384


'az.monitor','Azuread','az'| foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         update-module $_ -force  |out-null
         import-module -name $_ -force  |out-null
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
        install-module -name $_ -allowclobber |out-null 
        import-module -name $_ -force  |out-null
    }
   #  Get-InstalledModule
}




 ###### Get az subscription


  fUNCTION GETAZSUBS {


$subscriptions = Get-AzSubscription | Select-Object SubscriptionId, name, TenantId, State

 
  
   $i = 1 

       $subslist = ''
         $mastersublist = ''

         foreach($subtoselect in $subscriptions)
         {
           $subobj = new-object PSObject 
 
           $subobj |  Add-Member -MemberType NoteProperty -name subnumber -Value  $i 
          $subobj |  Add-Member -MemberType NoteProperty -Name subscriptionname -Value  $($subtoselect.name) 
           $subobj |    Add-Member -MemberType NoteProperty -Name Tenant -Value "$($subtoselect.Tenantid)"
  
          [array]$mastersublist += $subobj
 
          $i++ 
 
     
         }
            
        # Display prompt for user to select subscriptions
        Write-Host "Select one or more by the number separated by ',' (comma)" -ForegroundColor Green

        # Display the list of subscriptions with numbers
        $mastersublist | Where-Object { $_.subnumber -ne $null } | ForEach-Object {
            Write-Host "$($_.subnumber) - $($_.subscriptionname)" -ForegroundColor Cyan
        }

        # Capture user input
         $subscriptionsselected = Read-Host "Select the number(s) next to the name of the Subscription separated by ','"

        # Display selected subscriptions
        Write-Host "Selected subscriptions: $subscriptionsselected"
        
  $substopopulate = $($subscriptionsselected).split(',') 


        foreach($subnum in $substopopulate)
        {
            $subselobj = new-object Psobject

            $subselobj | add-member -MemberType NoteProperty -Name Subscriptionname -value ($mastersublist | where subnumber -eq $($subnum)).subscriptionname
            #$subselobj
            [array]$subslist += $subselobj


        }

  # $subslist
 

      return $subslist


 }

  
 
$subs =''

$subs = GETAZSUBS
$subs


$roles = @('Owner','Contributor') #These roles at the sub level if have email will be added to an action group to receive service health alerts
#$roles = @('Contributor') #These roles at the sub level if have email will be added to an action group to receive service health alerts

#Enable one of the following based on if there are specific groups that have roles you DON'T want included in health alerts
#$groupsToSkip = @('Jl','Avengers')
$groupsToSkip = @() #if none

### Generate randon number for rule uniqueness
$randomNumber = Get-Random -Minimum 1 -Maximum 101
Write-Output $randomNumber

#############################################
## Resourcegroup create function 
##################
function NEWRGCREATE 
{

    $rgloclist = ''

     $rglocationsnumbers =   get-azlocation  | select location | sort-object location 

     $i = 1 

     foreach($locationname in $rglocationsnumbers)
     {
       $locationsbj = new-object PSObject 
 
      $locationsbj |  Add-Member -MemberType NoteProperty -Name Locationnumber -Value  $i 
       $locationsbj |    Add-Member -MemberType NoteProperty -Name Location_Region -Value "$($locationname.Location)"
  
      [array]$rgloclist += $locationsbj
 
      $i++ 
 
     
     }
 
 
         # Display the list of subscriptions with numbers
        $rgloclist  | Where-Object { $($_.Locationnumber) -ne $null } | ForEach-Object {
            Write-Host "$($_.Locationnumber) - $($_.Location_Region)" -ForegroundColor Cyan
        }

 

[array]$regionsselected =  read-host " select the number next to the Resourcegroup location desired :"

$regionsselected 

        $relocselected = $rgloclist | Where Locationnumber -eq $($regionsselected) | Select Location_Region


            $newrgname  = read-host " select a RG name: " 
       
           $newrg =  New-azresourcegroup -Name "$($newrgname)_DoNoDelete" `
                -Force -Verbose `
                -location $($relocselected.Location_Region) `
                -Tag @{owner = 'jerry wolff'  ; Purpose = 'Service health alerts'} `
            
            $rg = $newrg 
 
    return $rg
}




function Find_rg
{
        set-azcontext -Subscription $($sub.Subscriptionname)
         $resourcegroupstoselect = ''
         $existingrgs =  get-azresourcegroup | select resourcegroupname, location

         $i = 1 
         $masterrglist = ''

         foreach($rgtoselect in $existingrgs)
         {
           $rgobj = new-object PSObject 
 
           $rgobj |  Add-Member -MemberType NoteProperty -name RGnumber -Value  $i 
          $rgobj |  Add-Member -MemberType NoteProperty -Name resourcegroupname -Value  $($rgtoselect.resourcegroupname) 
           $rgobj |    Add-Member -MemberType NoteProperty -Name Location_Region -Value "$($rgtoselect.Location)"
  
          [array]$masterrglist += $rgobj
 
          $i++ 
 
     
         }
 
 
           
        # Display prompt for user to select subscriptions
        Write-Host "Select the resourcegroup to contain the alert and action group :" -ForegroundColor Green

        # Display the list of subscriptions with numbers
        $masterrglist | Where-Object { $_.RGnumber -ne $null } | ForEach-Object {
            Write-Host "$($_.RGnumber) - $($_.resourcegroupname)" -ForegroundColor Cyan
        }
    
        [array]$resourcegrouptoselect =  read-host " select the number next to the name of the Resourcegroup :"

      write-host "  $resourcegrouptoselect " 

           $resourcegrouptoselect  | ForEach-Object {
 
            $homerg = $masterrglist | Where RGnumber -eq $_  | Select-Object -ExpandProperty resourcegroupname
 
         }




         $rg = get-azresourcegroup -Name $homerg

      return $rg
 

}
 
<################################################
#### select impacted areas for alerts - only the areas you care about 
 #>

 $masterregionlist = ''
 $locationsnumbers =   get-azlocation  | select location | sort-object location 

 $i = 1 

 foreach($locationname in $locationsnumbers)
 {
   $locationsbj = new-object PSObject 
 
  $locationsbj |  Add-Member -MemberType NoteProperty -Name Locationnumber -Value  $i 
   $locationsbj |    Add-Member -MemberType NoteProperty -Name Location_Region -Value "$($locationname.Location)"
  
  [array]$masterregionlist += $locationsbj
 
  $i++ 
 
     
 }
 
 
         # Display the list of subscriptions with numbers
        $masterregionlist  | Where-Object { $($_.Locationnumber) -ne $null } | ForEach-Object {
            Write-Host "$($_.Locationnumber) - $($_.Location_Region)" -ForegroundColor Cyan
        }

 

[array]$regionsselected =  read-host " select the number next to the name of the location(s) separated by comma :"

$regionsselected 

 $locations = ''

  $regionsselected.split(',')  | ForEach-Object {
    $locationname = $masterregionlist | Where Locationnumber -eq $_  | Select-Object -ExpandProperty Location_Region
    [array]$locations += "$locationname"
}

$locations = $locations | Where-Object {$_ -ne ''} 
 
   $impactedregions = '"{0}"' -f ($($locations) -join '","')

   $impactedregions  


###########################
####  Service type to monitor

 

##################################


$nameOfAlertRule = "Core-ServiceHealth-AR-DONOTRENAMEORDELETE_$randomNumber"
$nameOfAlertRuleDesc = "Core ServiceHealth Alert Rule DO NOT DELETE OR RENAME"
$nameOfActionGroup =  "CoreSHAG$randomnumber" 

$nameOfActionGroupShort = "CoreSHAG$randomNumber" #12 characters or less



$servicehealthlocation = "Global"


#set this to true if the existing action group members should be replaced completely if the action group already exists instead of having new people appended to existing members
$REPLACENOTADD = $false

 

foreach ($sub in $subs | where-object {$_ -ne $null -or $_ -ne ''})
{

    $ErrorActionPreference = "Silentlycontinue"

    $errorFound = $false
 
    #Set context to target subscription
    Write-host "Subscription $($sub.subscriptionname)" -ForegroundColor CYAN


    $subid = get-azsubscription -SubscriptionName $($sub.subscriptionname)

    try {
        Set-AzContext -Subscription $($sub.subscriptionname) -ErrorAction Stop
    }
    catch {
        Write-Error "!! Subscription error:"
        Write-Error $_
        $errorFound = $true
    }

    if(!$errorFound) #if no error
    {
        $subScope = "/subscriptions/$($subid.id)"

        $emailsToAdd = @()

        set-azcontext -subscription $($sub.subscriptionname) 



                ## select resourcegroup to hold alert and action group 

                ## RG selection

                $resourcegroupcreate = read-host " Select an existing resourcegroup or create new : (Y/N) "

                switch ($resourcegroupcreate)
                {

                    "N" {
            
                            $rg = NEWRGCREATE 
                        }


                    "Y" {

                           

                            $rg = find_rg

                              $rg 
                    }

                Default {
                        "No matches - EXITING TO RESTART"
                        break
                    }
      
      
                }

$nameOfCoreResourceGroup = "$($rg.resourcegroupname)"

        #check the core RG exists
        $coreRG = Get-AzResourceGroup -Name $nameOfCoreResourceGroup -ErrorAction SilentlyContinue
 
        foreach($role in $roles)
        {
            Write-Verbose "Role $role"
            #Note this will get all of this role at this scope and CHILD (e.g. also RGs so we have to continue to filter)
            $members = Get-AzRoleAssignment -Scope $subScope -RoleDefinitionName $role
            #$members | ft objectType, RoleDefinitionName, DisplayName, SignInName

            foreach ($member in $members) {
                if($member.scope -eq $subScope) #need to check specific to this sub and not inherited from MG or a child RG
                {


                    Write-Verbose "$sub,$($member.DisplayName),$($member.SignInName),$($contrib.ObjectType)"

                    #Change to support groups and enumerate for members via Get-AzADGroupMember -GroupDisplayName
                    if($member.ObjectType -eq 'Group')
                    {
                        $groupinfo = get-azadgroup -DisplayName  $($member.DisplayName)
                        #check if the group should be excluded ($groupsToSkip)
                        if($groupsToSkip -notcontains $member.DisplayName)
                        {
                            Write-Verbose "Group found $($member.DisplayName) - Expanding"
                            $groupMembers = Get-AzADGroupMember -GroupObjectId $($groupinfo.id)
                            $emailsToAdd += $groupmembers | Where-Object {$_.Mail -ne $null} | select-object -ExpandProperty Mail #we only add if has an email attribute
                        }
                    }

                    #Can also check the email for users incase their email is different from UPN via Get-AzADUser -UserPrincipalName
                    if($member.ObjectType -eq 'User')
                    {
                        Write-Verbose "User found $($member.SignInName) - Checking for email attribute"
                        $userDetail = Get-AzADUser -UserPrincipalName $member.SignInName
                        if($null -ne $userDetail.Mail)
                        {
                            $emailsToAdd += $userDetail.Mail
                        }
                    }
                }
            }
        }

        $emailsToAdd = $emailsToAdd | Select-Object -Unique #Remove duplicated, i.e. if multiple of the roles
        Write-Verbose "Emails to add: $emailsToAdd"

        #Look for the Action Group
        $AGObj = Get-AzActionGroup | Where-Object { $_.Name -eq $nameOfActionGroup }
        $AGObjFailure = $false
        if($null -eq $AGObj) #not found
        {
            Write-Output "Action Group not found, creating."
            if($emailsToAdd.Count -gt 0)
            {
                #Note there is also the ability to link directly to an ARM role which per the documentation only is if assigned AT THE SUB and NOT inherited
                $emailReceivers = @()
                foreach ($email in $emailsToAdd) {
                    #$emailReceiver = New-AzActionGroupReceiver -EmailReceiver -EmailAddress $email -Name $email
                  $receivername = New-AzActionGroupEmailReceiverObject    -EmailAddress $email -Name $email

 
         
                    $emailReceivers += $receivername
                } 


                #$actiongroup = new-AzActionGroup -ResourceGroupName $nameOfCoreResourceGroup -Name $nameOfActionGroup -GroupShortName  $nameOfActionGroupShort -Location $servicehealthlocation -EmailReceiver  $emailReceivers 

            try {
                # Attempt to create a new action group
                set-azcontext -Subscription $($sub.subscriptionname)

             $actiongroup = new-AzActionGroup -ResourceGroupName $nameOfCoreResourceGroup -Name $nameOfActionGroup -GroupShortName  $nameOfActionGroupShort -Location $servicehealthlocation -EmailReceiver  $emailReceivers 

            } catch {
                # Check if the error message contains the specific text
                if ($_.Exception.Message -like "*The subscription is not registered to use namespace 'microsoft.insights'*") {
                    Write-Host "Error: The subscription is not registered to use namespace 'microsoft.insights'."
                    Write-Host "Attempting to register the namespace..."

                    # Register the namespace
                    Register-AzResourceProvider -ProviderNamespace "microsoft.insights"
                    start-sleep -Seconds 30
                    Write-Host "Namespace 'microsoft.insights' registered successfully. Please try running the command again."
                } else {
                    # Handle other errors
                    Write-Host "An unexpected error occurred: $($_.Exception.Message)"
                }
            }

                                ##time to allow action group creation

                start-sleep -Seconds 30

                ##enable Action group
 
                 update-AzActionGroup -ActionGroupName $($actiongroup.Name) -ResourceGroupName $nameOfCoreResourceGroup    -Enabled
                     
                
                
                $AGObj = Get-AzActionGroup | Where-Object { $_.Name -eq $nameOfActionGroup }
            }
            else
            {
                Write-Error "!! Could not create action group for subscription $sub as no valid emails found. This will also stop alert rule creation"
                $AGObjFailure = $true
            }
        }
        else
        {
            if(!$REPLACENOTADD)
            {
                #Is the list matching the current emails
                $currentEmails = $AGObj.EmailReceiver | Select-Object -ExpandProperty EmailAddress

                #need to check it is new ones added so side indicator would be => as would be in the emails to add
                $differences = Compare-Object -ReferenceObject $currentEmails -DifferenceObject $emailsToAdd | Where-Object { $_.SideIndicator -eq "=>"} -ErrorAction Ignore
                if($null -ne $differences) #if there are differences
                {
                    #add them together then find just the unique (we add the existing as could be manually added emails we want to keep)
                    $emailstoAdd += $currentEmails
                    $emailsToAdd = $emailsToAdd | Select-Object -Unique
                }
            }

            #Now update the action group
            $emailReceivers = @()
            foreach ($email in $emailsToAdd) {
              
                $emailReceiver = New-AzActionGroupEmailReceiverObject    -EmailAddress $email -Name $email
                     
                    $emailReceivers += $emailReceiver
            }

            try
            {
                update-azactionGroup -ResourceGroupName $nameOfCoreResourceGroup -Name $nameOfActionGroup -ShortName $nameOfActionGroupShort -EmailReceiver  $emailReceivers
            }
            catch
            {
                Write-Error "!! Error updating action group for $sub"
                Write-Error $_
                $emailReceivers
            }
        }

        #Look for the Alert Rule
        $ARObj = Get-AzActivityLogAlert | Where-Object { $_.Name -eq $nameOfAlertRule }


        #If wanted to find if ANY Alert Rule existed for Service Health and then could add an -and (ANYARSHFound -ne $null) to below condition
        #$ANYARSHFound = Get-AzActivityLogAlert | Format-List | out-string | select-string "`"equals`": `"ServiceHealth`""

        if(($null -eq $ARObj) -and (!$AGObjFailure)) #not found and not a failure creating the action group
        {
            Write-Output "Alert Rule not found, creating."
            $location = 'Global'
            $condition1 = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject -Field 'category' -Equal 'ServiceHealth' 
            $condition2 = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject -Field "properties.impactedServices[*].ImpactedRegions[*].RegionName"  -ContainsAny "$impactedregions"
            #$condition3 = New-AzActivityLogAlertAlertRuleAnyOfOrLeafConditionObject -Field "properties.impactedServices[*].ServiceName"  -ContainsAny "$Servicetypes"
 
            $actionGroupsHashTable = @{ Id = $AGObj.Id; WebhookProperty = "" }

            New-AzActivityLogAlert -Location $location -Name $nameOfAlertRule -ResourceGroupName $nameOfCoreResourceGroup -Scope $subScope -Action $actionGroupsHashTable -Condition $condition1, $condition2 `
                -Description $nameOfAlertRuleDesc -Enabled $true 
        }
    }
    Write-Output ""
}

 
   get-AzActivityLogAlert  -Name $nameOfAlertRule -ResourceGroupName $nameOfCoreResourceGroup



