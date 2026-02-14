
<#
.SYNOPSIS  
 script to create custom roles - Wizard 
.DESCRIPTION  
  script to create custom roles - Wizard 
.EXAMPLE  
    Create_Customer_Azure_Role 
Version History  
v1.0   - Initial Release  
 

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

#> 

 
$perms = ''
$ErrorActionPreference = 'Continue'
 
 Connect-AzAccount 

$Subscriptions = Get-AzSubscription  


$subscription_selected = $Subscriptions | ogv -title "Select susbscription for custom role: " -PassThru | Select  name, id

$subscription_selected 


 set-azcontext -subscription $subscription_selected.Name

 Clear-Content "c:\temp\roledetailedactions.html"

 ###############   Get all provider actions 

 $provider_actions = Get-AzProviderOperation  | select -Property *



 #################################################  Select category for new custom role 


  #$provider_Categories =  $provider_actions | ogv -Title "Select filter for Provider actions" -PassThru | select Operation, OperationName, ProviderNamespace, ResourceName, Description, IsDataAction
  $provider_Categories =  $provider_actions |  select providernamespace -unique  | ogv -Title "Select filter for Provider actions" -PassThru |  select providernamespace 
  $provider_Categories


 #################################### Collect all Custom role actions 
 
 

$providerscopeactions =  Get-AzProviderOperation | where providernamespace -eq "$($provider_Categories.ProviderNamespace)"

$customRoleActions = $providerscopeactions | ogv -Title " Select actions for the custom role" -PassThru | select  ProviderNamespace, Operation, OperationName, Description, IsDataAction

$customRoleActions |  select  ProviderNamespace, Operation, OperationName, Description, IsDataAction | export-csv c:\temp\$($provider_Categories.ProviderNamespace)_role_actions.csv -NoTypeInformation

$provideractionrights = ''





            foreach($providerSpecificaction in $customRoleActions)
            {
           

                $category =    ($($providerSpecificaction.Operation).split('/')[0]).split('.')[1]
                

                       $actionobj = new-object PSObject 
                       $actionobj | Add-Member -MemberType NoteProperty -name  Category -value $($providerSpecificaction.ProviderNamespace)
                       $actionobj | Add-Member -MemberType NoteProperty -name  Roleprovider -value $($providerSpecificaction.Operation).split('/')[0]                             
                       $actionobj | Add-Member -MemberType NoteProperty -name  RoleSection -value $($providerSpecificaction.Operation).split('/')[1]  
                       $actionobj | Add-Member -MemberType NoteProperty -name  Operation -value "$($providerSpecificaction.Operation)"     
                       $actionobj | Add-Member -MemberType NoteProperty -name  OperationName -value "$($providerSpecificaction.OperationName)"  
                       $actionobj | Add-Member -MemberType NoteProperty -name  Description -value "$($providerSpecificaction.Description)" 
                       $actionobj | Add-Member -MemberType NoteProperty -name  Action -value $($providerSpecificaction.Operation).split('/')[-1] 
                       $actionobj | Add-Member -MemberType NoteProperty -name  IsDataAction  -value $($providerSpecificaction.IsDataAction)                   
                       [array]$provideractionrights += $actionobj

  
}

$provideractionrights


 
############################  Create Role

 $RoleDefinitionaname = Read-Host " enter name of Role to be created with selections" :
 $RoleDefinitionDescription = Read-Host " enter name of role description  " :

#$role = Get-AzRoleDefinition "$RoleDefinitionaname"

$role = Get-AzRoleDefinition -Name "Virtual Machine Contributor"

 $role.ID =$null
$role.IsCustom = $True
$role.name = "$RoleDefinitionaname"
$role.Description = "$RoleDefinitionDescription"
$role.Actions.RemoveRange(0,$role.Actions.Count)

foreach($perm in $provideractionrights) 
{

        Foreach($permoperation in $perm | where operation -ne $null)
        {
            $role.Actions.Add("$($permoperation.Operation)")
 

        }
}
 
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add("/subscriptions/$($subscription_selected.id)")


 $newrole = $role | ConvertTo-Json |out-file  c:\temp\newrole.json

 
 New-AzRoleDefinition -role $role  


 ################## Option to us json input file for role creation
 #New-AzRoleDefinition -InputFile c:\temp\newrole.json

 

 

Get-AzRoleDefinition | ? {$_.IsCustom -eq $true} | FT Name, IsCustom
 
############ Option to view Json Role file
 
#invoke-item c:\temp\newrole.json

Get-AzRoleDefinition | where name -eq $($role.name)  #| Remove-AzRoleDefinition -Verbose -force 

 

 

