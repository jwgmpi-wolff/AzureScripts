Connect-azaccount -Identity 


$sub = get-azsubscription -SubscriptionName wolffentpSub

$resourceGroupName = "jwgovernance"
$alertRuleName = "VMQuotaAlert"
$scope = "/subscriptions/$($SUB.ID)"
$metricName = "Quota"
$quotaName = "Standard DSv3 Family vCPUs"
$region = "West US 2"
$threshold = 10  # Set your desired threshold percentage
$nameOfActionGroup = "QuotaManagers"
$nameOfActionGroupShort = "QuotaMgrs"
$targetResourceType = "Microsoft.Compute/virtualMachines"  # Specify the resource type




#############################################
## Resourcegroup create function 
##################
function NEWRGCREATE 
{

            $newrgname  = read-host " select a RG name: " 
           $location = get-azlocation | ogv -Title " select a region to hold RG :" -PassThru | Select displayname, location

 
           $newrg =  New-azresourcegroup -Name "$($newrgname)_DoNoDelete" `
                -Force -Verbose `
                -location $($location.location) `
                -Tag @{owner = 'jerry wolff'  ; Purpose = 'Service health alerts'} `
            
            $rg = $newrg 
 
    return $rg
}


$subsriptions = get-azsubscription

 
 ############################   Get region/Location for request

        $locname  = Get-azLocation | `
                    select displayname, Location | `
                    Out-GridView -PassThru -Title "Choose a location"


            $regionlist = $locname



########################  Get Sku Family 

      $regionquotausage =    Get-AzVmUsage –Location $($regionlist.DisplayName)   -ErrorAction SilentlyContinue

 
 
   $regionquotaselected =  $regionquotausage    |`
       Out-GridView -Title " Select Sku Family quota to add alert to: "  -PassThru | select name, CurrentValue, limit 
 
  #$regionquotaselected.Name.Value
  
  
 

$roles = @('Owner','Contributor') #These roles at the sub level if have email will be added to an action group to receive quota alerts

# Create action group
     foreach($role in $roles)
        {
            $subScope = "/subscriptions/$($sub.SubscriptionId)"

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
        $emailsToAdd


############### Resourcegroup new or exsiting to use 
##########
               $resourcegroupcreate = read-host " Select an existing resourcegroup or create new : (Y/N) "

                switch ($resourcegroupcreate)
                {

                    "N" {
            
                            $rg = NEWRGCREATE 
                        }


                    "Y" {

                             $rg = get-azresourcegroup | ogv -title " select a resourcegroup to hold resources:  " -passthru | Select resourcegroupname
 
                              $rg 
                    }


      
                }

        $nameOfCoreResourceGroup = "$($rg.resourcegroupname)"

        #check the core RG exists
        $coreRG = Get-AzResourceGroup -Name $nameOfCoreResourceGroup -ErrorAction SilentlyContinue


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


                $actiongroup = new-AzActionGroup -ResourceGroupName $nameOfCoreResourceGroup -Name $nameOfActionGroup -GroupShortName  $nameOfActionGroupShort -Location $region -EmailReceiver  $emailReceivers 

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


# Define the new values for the parameters
$newScheduledQueryRuleName = Read-Host "Enter the quota alert name:"

$actiongroups = Get-AzActionGroup | Out-GridView -Title "Select action group to assign:" -PassThru | Select-Object *

$AGObj = Get-AzActionGroup | Where-Object { $_.Name -eq $($actiongroups.Name) }

# Load the JSON template
# Define the parameters
$parameters = @{
    "scheduledqueryrules_template_alert_rule_name" = "$newScheduledQueryRuleName"
    "actionGroups_QuotaManagers_externalid"        = @("$($agobj.id)")
}

# Read the template and parameters JSON files
$template = Get-Content -Path "C:\temp\ExportedTemplate-wolffnorthcentalvnetrg\template.json" -Raw | ConvertFrom-Json
$quotaparams = Get-Content -Path "C:\temp\ExportedTemplate-wolffnorthcentalvnetrg\parameters.json" -Raw
$quotaparamsjson = $quotaparams | ConvertFrom-Json  

# Clean up existing parameters in the template
$template.parameters.PSObject.Properties.GetEnumerator() | ForEach-Object {
    $template.parameters.PSObject.Properties.Remove("$($_.name)")
}

# Define the new parameters
$sparameter = (("scheduledqueryrules_$newScheduledQueryRuleName").trim().replace(' ','_')).trim()
$aparameter = (("actionGroups_$($agobj.name)_externalid").replace(' ','_')).trim()

# Add the new parameters to the template
$template.parameters = @{
    $sparameter = @{
        "type"  = "string"
        "defaultValue" = "$newScheduledQueryRuleName"
    }
    $aparameter = @{
        "type"  = "array"
        "defaultValue" = @("$($agobj.id)")
    }
}

# Modify the resources array in the template
foreach ($resource in $template.resources) {
    if ($resource.type -eq "microsoft.insights/scheduledqueryrules") {
        $resource.name = "[parameters('$sparameter')]"
        $resource.properties.displayName = "[parameters('$sparameter')]"
        $resource.properties.actions.actionGroups = "[parameters('$aparameter')]"
    }
}

# Recreate the query based on the selected SKUs
$query = @"
arg("").QuotaResources 
| where subscriptionId =~ '$subscriptionId'
| where type =~ 'microsoft.compute/locations/usages'
| where isnotempty(properties)
| mv-expand propertyJson = properties.value limit 400
| extend
    usage = propertyJson.currentValue,
    quota = propertyJson.['limit'],
    quotaName = tostring(propertyJson.['name'].value)
| extend usagePercent = toint(usage)*100 / toint(quota)
| project-away properties
| where location in~ ($location)
| where quotaName in~ ('$(($regionquotaselected.name.value) -join "','")')
"@

# Replace the query in the allOf array
foreach ($item in $template.resources.properties.criteria.allOf) {
    if ($item.PSObject.Properties.Name -eq 'query') {
        $item.query = $query
    }
}

# Convert the template to a JSON object
$updatedTemplate = $template | ConvertTo-Json -Depth 32

# Replace Unicode escape sequences with actual characters
$updatedTemplateclean = ($updatedTemplate -replace '\\u0027', "'").replace('\\u0027', "'")

# Save the updated template to a file
$updatedTemplateclean | Out-File -FilePath C:\temp\newquotatemplate.json 

# Deploy the resource group
$deploymentname = ($newScheduledQueryRuleName) -replace(' ','')
 
 
  $deploymentname = ($newScheduledQueryRuleName) -replace(' ','')
   New-AzResourceGroupDeployment -name $deploymentname -ResourceGroupName $resourceGroupName -TemplateFile C:\temp\newquotatemplate.json #   -TemplateParameterObject $parameters #-templateparameterobject $parametersjson -DeploymentDebugLogLevel All    -TemplateParameterFile C:\temp\newquotaparamstemplate.json 
     
 





