 
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

    Script Name: update_allowed_sku_policy_and_assignment_from_master_in_storage_regional.ps1

    Description: 

    summary of the PowerShell script:

 Description: 
     this PowerShell script performs several operations related to Azure Policy management and storage account handling.
      Here’s a summary of its functions and operations:

    Environment Setup:
    Suppresses Azure PowerShell breaking change warnings.
    Connects to Azure using managed identity.
    Storage Account and Container Setup:
    Selects the subscription and resource group.
    Retrieves subscription and tenant information.
    Defines storage account and container names for policy data and history.
    Azure Context Setup:
    Sets the Azure context to the selected subscription and tenant.
    Retrieve Allowed SKUs and Regions:
    Prompts the user to select regions to block using an interactive grid view.
    Retrieves the list of allowed SKUs from a CSV file stored in the specified storage container.
    Policy Definition:
    Checks if the allowed SKUs list is not empty.
    Defines policy parameters for allowed SKUs and regions.
    Constructs the policy rule to audit virtual machines and scale sets that do not match the allowed SKUs in the specified regions.
    Converts the policy definition to JSON and creates a new policy definition in Azure.
    Policy Assignment:
    Writes the updated policy definition to a JSON file and uploads it to the storage account.
    Retrieves the existing policy assignment and removes it if it exists.
    Reassigns the policy definition with the updated parameters to the subscription.
    Logging and Error Handling:
    Outputs the policy definition JSON for debugging.
    Handles errors and outputs relevant messages to the console.
    This script ensures that only specified SKUs are allowed in the selected regions, and it maintains a history 
     of policy updates in a storage account

#>

#requiredversion 5.1
   Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings 'true'
 
connect-azaccount -identity

 

################  Set up storage account and containers ################
$subscriptionselected = 'wolffentpsub'
$resourcegroupname = 'jwgovernance'
$subscriptioninfo = get-azsubscription -SubscriptionName $subscriptionselected 
$TenantID = $subscriptioninfo | Select-Object tenantid
$storageaccountname = 'policydatasa'
$storagecontainer = 'policyupdates'
$historycontainer = 'policyhistory'
$region = 'eastus'
#################
 
 
# Set Azure context
Set-AzContext -Subscription $($subscriptioninfo.Name) -Tenant $subscriptioninfo.TenantId

# Get SKUs to block
# Get SKUs to block
$policyallowedregions = get-azlocation | Out-GridView -Title "Select Regions to block:" -PassThru | Select  displayname 

# Get SKUs to block
$allowedskuslist  


######################## Storage account info for source files and history files

$currentallowedlistname = "allowedskus.csv"



$StorageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourcegroupname  –StorageAccountName $storageaccountname).value | select -first 1
$destContext = New-azStorageContext  –StorageAccountName $storageaccountname `
                 -StorageAccountKey $StorageKey



if(get-AzStorageBlob -Blob $currentallowedlistname -Container $storagecontainer -Context $destContext -ErrorAction SilentlyContinue)
{

    $currentallowedlist = get-AzStorageBlob -Blob $currentallowedlistname -Container $storagecontainer -Context $destContext

 
      $currentallowedlistcontent = Get-AzStorageBlobContent -Blob $currentallowedlistname -Container $storagecontainer    -Context $destContext -Force


    $allowedskuslist = import-csv   "$env:SystemRoot\System32\$currentallowedlistname"
   

}
Else 
{
    write-warning "$currentallowedlistname list does not exist in $($destContext.BlobEndPoint)" -ErrorAction Stop

}

################################################################################ Build policy #########


if ($allowedskuslist.Count -lt 1) {
    Write-Warning "Nothing selected" -ErrorAction Stop
} else {

# Define the policy parameters
$policyParameters = @{
    "listofallowedskus" = @{
        "type" = "Array"
        "metadata" = @{
            "displayName" = "Allowed SKU types"
            "description" = "Value of the SKU, such as Standard_Xasxxxx_vx"
        }
        "defaultValue" = $($allowedskuslist.name)
    }
    "listOfAllowedLocations" = @{
        "type" = "Array"
        "metadata" = @{
            "displayName" = "Allowed locations"
            "description" = "The regions to apply the policy to."
        }
        "defaultValue" = @($policyallowedregions.DisplayName)
    }
}

# Define the policy rule
$policyRule = @{
    "if" = @{
        "allOf" = @(
            @{
                "field" = "type"
                "in" = @("Microsoft.Compute/virtualMachines", "Microsoft.Compute/virtualMachineScaleSets")
            },
            @{
                "field" = "Microsoft.Compute/virtualMachines/sku.name"
                "notIn" = "[parameters('listofallowedskus')]"
            },
            @{
                "field" = "location"
                "in" = "[parameters('listOfAllowedLocations')]"
            }
        )
    }
    "then" = @{
        "effect" = "audit"
    }
}

   # Define the policy definition
    $policyDefinition = @{
        "properties" = @{
            "displayName" = "allow only Specific SKUs"
            "description" = "This policy allow only  the creation of specific SKUs."
            "policyRule" = $policyRule
            "parameters" = $policyParameters
            "metadata" = @{
                "category" = "allowonly ions"
            }
        }
    }

    # Convert the policy definition to JSON
    $policyDefinitionJson = $policyDefinition | ConvertTo-Json -Depth 10

    # Output the JSON for debugging
    Write-Output "Policy Definition JSON:"
    Write-Output $policyDefinitionJson

    # Create the new policy definition
    New-AzPolicyDefinition -Name "allowonlySpecificSKUs" -Policy $policyDefinitionJson -Mode All

    Write-Output "Policy created successfully."
 }


#######################################################


 $updatedpolicy = "updatedallowedskupolicy.json"

 
     $newpolicydefiniton =      $policyDefinitionJson   

     $policyDefinitionJson  | out-file  $updatedpolicy

 
     
        ################################## Add raw content to Variable
 
 
     $date = get-date -Format 'yyyyMMddHHmmss'   

   
        ##################  Write updated parameters file to Storage account 

              Set-azStorageBlobContent -Container $historycontainer -Blob "$($updatedpolicy)$date"  -File "$($updatedpolicy)"  -Context $destContext -Force

 

        ############## Apply updates to Policy parameters and reapply to Definition
 $policytoassign = Get-AzPolicyDefinition -Name "allowonlySpecificSKUs"

############## Test/ Validation Policy and values

$policydefinitionproperties = Get-AzPolicyDefinition -Name "$($policytoassign.name)" -SubscriptionId $subscriptioninfo.Id

$policydefinitionproperties
$($policydefinitionproperties.metadata) | fl *

Write-Host "$($policydefinitionproperties.metadata)" -ForegroundColor Green
Write-Host "$($policydefinitionproperties.parameter.listofallowedskus.displayName)" -ForegroundColor Green
Write-Host "$($policydefinitionproperties.policyrule)" -ForegroundColor Green
Write-Host "$($policydefinitionproperties.description)" -ForegroundColor Green

$($policydefinitionproperties.parameter).listofallowedskus.defaultvalue

##################################### Reassign subscription to update policy
 
######### Remove old assignment on resource
try {
    $PolicyAssignment = Get-AzPolicyAssignment -PolicyDefinitionId $($policytoassign.id)

    if ($PolicyAssignment) {
        # Remove existing policy assignment if needed

        # Reassign Policy Definition
        $listofallowedskus = @{'listofallowedskus' = $($policydefinitionproperties.parameter).listofallowedskus.defaultvalue}

        # Ensure the Name parameter is provided
        $policyid = "$($policytoassign.id)"

        if (-not [string]::IsNullOrEmpty($policyid)) {
          $policyassignment = Get-AzPolicyAssignment -PolicyDefinitionId $($policyid)  
          
           Update-AzPolicyAssignment -name $($policyassignment.Name)   -PolicyParameterObject $listofallowedskus -NonComplianceMessage @{Message = "Stop making mistakes - I will find you"}
        
        
        } else {
            Write-Host "The Name parameter is null or empty. Please provide a valid Name." -ForegroundColor Red
        }
    } else {
        Write-Host "Policy: $($policydefinitionproperties.displayName) not assigned yet to any level ******" -ForegroundColor Black -BackgroundColor White
    }
} catch {
    Write-Host "An error occurred: $_" -ForegroundColor Cyan
}

################  Write json policy definition to history container

 Set-azStorageBlobContent -Container $historycontainer -Blob "$updatedpolicy"  -File "$updatedpolicy"  -Context $destContext -Force






