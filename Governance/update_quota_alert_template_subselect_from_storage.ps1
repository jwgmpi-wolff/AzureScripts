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

Description: 
 Azure PowerShell Script for Quota Alerts
This Azure PowerShell script automates the creation and management of quota alerts in a specified Azure 
subscription. The script performs a series of tasks to ensure that the necessary infrastructure is in 
place and that alerts are configured correctly.

Key Functions and Steps
Pre-setup
Set Maximum Variable and Function Count:

Limits for variables and functions are set to ensure the script runs smoothly.
Connect to Azure Account:

The script connects to the Azure account using managed identity for authentication.
Suppress Azure PowerShell Breaking Change Warnings:

Suppresses warnings about breaking changes in Azure PowerShell to avoid disruptions.
Setup Storage Account and Resource Group
Select Subscription:

The script sets the subscription in which resources will be managed.
Define Storage Account Information:

Specifies the names and regions for storage accounts and containers used for storing templates 
and alert configurations.

Set Azure Context:

Sets the Azure context to the specified subscription and tenant.
Create Resource Group if it doesn't exist:

Checks if the specified resource group exists; if not, it creates a new one with the provided tags and location.
Create Storage Account if it doesn't exist:

Checks for the existence of the specified storage account; if not found, it creates a new 
storage account with specified configurations.

Create Storage Containers if they don't exist:

Ensures the specified storage containers are present in the storage account; creates them if they do not exist.
Set Storage Context:

Retrieves storage account keys and sets the storage context for subsequent operations.
Create or Select Resource Group
Function to Create New Resource Group:

A function (
NEWRGCREATE
) is defined to create a new resource group based on user input and selected region.
Select Subscription for Alerts and Action Group:

Prompts the user to select a subscription for setting up alerts and action groups.
Get Region/Location for Request:

Prompts the user to select a location from available Azure regions.
Get SKU Family:

Retrieves and prompts the user to select a SKU family quota to add an alert to.
Create Action Group
Prepare Email Receivers:
Identifies users and groups with specific roles (Owner, Contributor) in the selected subscription.
Collects email addresses of these users and groups to add them to the action group for receiving quota alerts.
Final Steps
Create or Update Action Group:

Checks if an action group exists; if not, creates a new one and adds the collected email addresses.
If the action group exists, updates it with any new email addresses not already included.
Generate and Deploy Alert Template:

Reads existing alert templates and parameters from storage.
Modifies the template to include user-specified alert names, action groups, and scopes.
Deploys the updated template to the selected resource group, creating the quota alert.
Summary
This script ensures that the necessary infrastructure (resource groups, storage accounts, 
containers) is in place, collects relevant user and group information, and sets up quota alerts 
in Azure. It automates the process of creating and managing quota alerts, making it easier to monitor
 and manage Azure resources efficiently.
 
#>

 $MaximumVariableCount = 8192
 $MaximumFunctionCount = 8192

Connect-azaccount -Identity 

  Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
   
#################  Connecto toe azure context based on login credentials 
#######  if connect-axaacount -Identity is used, the managed identity will be used for context in the execution 
#######  for Azure government tenant use  , run connect-azconnect -Environment AzureUSGovernment


connect-azaccount    -identity 

import-module az.storage
import-module Az.Resources 


$subscriptionselected = 'wolffentpsub'



################  Set up storage account ################


$sargname = 'jwgovernance'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'wolfftemplatesa'
$storagecontainer = 'alertscntr'
$templatecontainer = 'alerttemplatescntr'

$region = 'eastus'

### end storagesub info

Set-azcontext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

 ####resourcegroup 
 try
 {
     if (!(Get-azresourcegroup -Location 'westus'  -erroraction "continue" ) )
    {  
        Write-Host "resourcegroup Does Not Exist, Creating resourcegroup  : $sargname Now"

        # b. Provision resourcegroup
        New-azresourcegroup -Name  $sargname -Location $region -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation" } -Verbose -Force
 
     
        Get-azresourcegroup    -ResourceGroupName  $sargname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Resourcegroup   Aleady Exists, SKipping Creation of resourcegroupname"
   
   }

    
 try
 {
     if (!(Get-AzStorageAccount -ResourceGroupName $sargname -Name $storageaccountname  -erroraction "continue" ) )
    {  
        Write-Host "Storage Account Does Not Exist, Creating Storage Account: $storageAccount Now"

        # b. Provision storage account
        New-AzStorageAccount  -ResourceGroupName $sargname  -Name $storageaccountname -Location $region -AccessTier Hot -SkuName Standard_LRS -Kind BlobStorage -Tag @{"owner" = "Jerry wolff"; "purpose" = "Az Automation storage write" } -Verbose 
 
        start-sleep 30

        Get-AzStorageAccount -Name   $storageaccountname  -ResourceGroupName  $sargname  -verbose
     }
   }
   Catch
   {
         WRITE-DEBUG "Storage Account Aleady Exists, SKipping Creation of $storageAccount"
   
   } 
 
             #Upload container user.json to storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $storagecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $storagecontainer -Context $destContext

                         
                        start-sleep 30

                        }
             }
        catch
             {
                Write-Warning " $storagecontainer container already exists" 
             }
       
             #download for templates container  storage account

        try
            {
                  if (!(get-azstoragecontainer -Name $templatecontainer -Context $destContext))
                     { 
                         New-azStorageContainer $templatecontainer -Context $destContext

                         
                        start-sleep 30

                        }
             }
        catch
             {
                Write-Warning " $templatecontainer container already exists" 
             }
       
    #############################################################

     


set-azcontext -Subscription $($subscriptioninfo.Name)  -Tenant $($TenantID.TenantId)



$StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $sargname  –StorageAccountName $storageaccountname).value | select -first 1
$destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
                 -StorageAccountKey $StorageKey


 
#############################################
## Resourcegroup create function 
##################
function NEWRGCREATE 
{

            $newrgname  = read-host " select a RG name: " 
          # $location = get-azlocation | ogv -Title " select a region to hold RG :" -PassThru | Select displayname, location
                                      # Define the list of supported regions
                            $supportedRegions = @(
                                'global',
                                'swedencentral',
                                'germanywestcentral',
                                'northcentralus',
                                'southcentralus',
                                'eastus2',
                                'eastus',
                                'westus',
                                'westus2',
                                'centralindia',
                                'southindia'
                            )

                                                    # Use Out-GridView to allow the user to select a region
                        $location = $supportedRegions | Out-GridView -Title "Select a Supported Region" -PassThru | select -First 1

                        # Check if a region was selected
                        if ($null -ne $location) {
                            Write-Output "You selected: $location"
                             
                        } else {
                            Write-Output "No region selected."
                            BREAK
                        }

                  
 
           $newrg =  New-azresourcegroup -Name "$($newrgname)" `
                -Force -Verbose `
                -location $($location) `
                -Tag @{owner = 'jerry wolff'  ; Purpose = 'Service health alerts'} `
            
            $rg = $newrg 
 
    return $rg
}


$subsriptionstoselect = get-azsubscription | ogv -title " select subscription for the alert and action group: " -PassThru | select *

 
$scope = "/subscriptions/$($subsriptionstoselect.ID)"
$metricName = "Quota"
$targetResourceType = "Microsoft.Compute/virtualMachines"  # Specify the resource type

 set-azcontext -Subscription $($subsriptionstoselect.name)


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
  
  
 
  $emailsToAdd = ''
$roles = @('Owner','Contributor') #These roles at the sub level if have email will be added to an action group to receive quota alerts

# Create action group
     foreach($role in $roles)
        {
            $subScope = "/subscriptions/$($subsriptionstoselect.id)"

            Write-Verbose "Role $role"
            #Note this will get all of this role at this scope and CHILD (e.g. also RGs so we have to continue to filter)
            $members = Get-AzRoleAssignment -Scope $subScope -RoleDefinitionName $role
             $members | ft objectType, RoleDefinitionName, DisplayName, SignInName

            foreach ($member in $members) {
                if($($member.scope) -eq $subScope -or $($member.scope) -like '*managementgroup*')  #need to check specific to this sub and not inherited from MG or a child RG
                {


                    Write-Verbose "$sub,$($member.DisplayName),$($member.SignInName),$($contrib.ObjectType)"

                    #Change to support groups and enumerate for members via Get-AzADGroupMember -GroupDisplayName
                    if($($member.ObjectType) -eq 'Group')
                    {
                        $groupinfo = get-azadgroup -DisplayName  $($member.DisplayName)
                        #check if the group should be excluded ($groupsToSkip)
                        if($groupsToSkip -notcontains $member.DisplayName)
                        {
                            Write-Verbose "Group found $($member.DisplayName) - Expanding"
                            $groupMembers = Get-AzADGroupMember -GroupObjectId $($groupinfo.id)
                             [array]$emailToAdd += $groupmembers | Where-Object {$_.Mail -ne $null} | select-object -ExpandProperty Mail #we only add if has an email attribute
                        }
                    }

                    #Can also check the email for users incase their email is different from UPN via Get-AzADUser -UserPrincipalName
                    $($member.ObjectType)
                    if($($member.ObjectType) -eq 'User')
                    {
                        Write-Verbose "User found $($member.SignInName) - Checking for email attribute"
                        $userDetail = Get-AzADUser -UserPrincipalName $member.SignInName
                        if($null -ne $($userDetail.Mail))
                        {
                            [array]$emailToAdd += $($userDetail.Mail)
                        }
                    }
                }
            }
        }

        $emailsToAdd = $emailToAdd | Select-Object -Unique #Remove duplicated, i.e. if multiple of the roles
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

                            # $rg = get-azresourcegroup | ogv -title " select a resourcegroup to hold resources:  " -passthru | Select resourcegroupname, Location
 
                             # $rg 

                             
                            # Define the list of supported regions
                            $supportedRegions = @(
                                'global',
                                'swedencentral',
                                'germanywestcentral',
                                'northcentralus',
                                'southcentralus',
                                'eastus2',
                                'eastus',
                                'westus',
                                'westus2',
                                'centralindia',
                                'southindia'
                            )

                                                    # Use Out-GridView to allow the user to select a region
                        $rg = $supportedRegions | Out-GridView -Title "Select a Supported Region" -OutputMode Single

                        # Check if a region was selected
                        if ($null -ne $selectedRegion) {
                            Write-Output "You selected: $selectedRegion"
                            # You can now use $selectedRegion in your subsequent commands
                            # Example:
                            # new-AzActionGroup -ResourceGroupName $resourceGroupName -Name $nameOfActionGroup -ShortName $nameOfActionGroupShort -Location $selectedRegion -Email $email -Webhook $webhook
                        } else {
                            Write-Output "No region selected."
                            BREAK
                        }

                    }


      
                }


        $resourcegroupname = $($rg.ResourceGroupName)

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

                $nameOfActionGroupraw = READ-HOST "No action group found in this sub: enter the name of an action group: " 
                $nameofActiongroup = ($nameOfActionGroupraw).replace(' ','').trim()
                $nameOfActionGroupShort = (($($nameOfActionGroupraw).Substring(0,11)).replace(' ','')).trim()



                $actiongroup = new-AzActionGroup -ResourceGroupName $nameOfCoreResourceGroup -Name $nameOfActionGroup -GroupShortName  $nameOfActionGroupShort -Location $($coreRG.Location)  -EmailReceiver  $emailReceivers 

                                ##time to allow action group creation

                start-sleep -Seconds 60

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
    "scopeParameterName"                           = @($scope)  # Ensure scope is an array
}


################ existing template parameters 
###### get parameters



$Alertjsonparamsfile = "parameters.json"

$jsonparamsblob = get-AzStorageBlob -Blob $Alertjsonparamsfile -Container $templatecontainer -Context $destContext 

 
[array]$Alertjsonparamscontent = Get-AzStorageBlobContent -Blob $Alertjsonparamsfile -Container $templatecontainer   -Context $destContext -Force

 $Alertparameters = get-Content -raw $($Alertjsonparamscontent.name)
$Alertparameters
 
 ############ use this is pulling from local files

# Read the template and parameters JSON files
#$template = Get-Content -Path "C:\temp\ExportedTemplate-wolffnorthcentalvnetrg\template.json" -Raw | ConvertFrom-Json
#$quotaparams = Get-Content -Path "C:\temp\ExportedTemplate-wolffnorthcentalvnetrg\parameters.json" -Raw
#$quotaparamsjson = $quotaparams | ConvertFrom-Json  

########## Get Policy template 



$Alertjsontemplate = "template.json"

$jsondefinitionblob = get-AzStorageBlob -Blob $Alertjsontemplate -Container $templatecontainer -Context $destContext

 
 [array]$alerttemplate = Get-AzStorageBlobContent -Blob $Alertjsontemplate -Container $templatecontainer    -Context $destContext -Force


$template = get-Content   $($alerttemplate.name)  -Raw | ConvertFrom-Json
$template





 ##############################################################################

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
    scopeParameterName = @{
        "type"  = "array"
        "defaultValue" = @($scope)  # Ensure scope is an array
    }
}

# Modify the resources array in the template
foreach ($resource in $template.resources) {
    if ($resource.type -eq "microsoft.insights/scheduledqueryrules") {
        $resource.name = "[parameters('$sparameter')]"
        $resource.properties.displayName = "[parameters('$sparameter')]"
        $resource.properties.actions.actionGroups = "[parameters('$aparameter')]"
        $resource.properties.scopes = "[parameters('scopeParameterName')]"
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
   New-AzResourceGroupDeployment -name $deploymentname -ResourceGroupName $resourceGroupName -TemplateFile C:\temp\newquotatemplate.json     #-TemplateParameterObject $parameters #-templateparameterobject $parametersjson -DeploymentDebugLogLevel All    -TemplateParameterFile C:\temp\newquotaparamstemplate.json 
     
 





