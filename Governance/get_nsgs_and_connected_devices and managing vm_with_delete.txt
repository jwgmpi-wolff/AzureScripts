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

Description : This PowerShell script automates the auditing and cleanup of Azure Network Security Groups (NSGs). 
It identifies NSGs that are unused or orphaned, generates detailed HTML reports, and removes unnecessary NSG and NIC 
resources to maintain a clean and compliant Azure environment.

Key Functions
1. Initialization
Sets maximum variable and function limits to support large-scale operations.
Authenticates to Azure using a managed identity.
Ensures required modules (microsoft.graph, Az.network) are installed and imported.
2. NSG-to-NIC Association Audit (Scan_NSGS)
Queries Azure Resource Graph to identify NSGs and their associated network interfaces (NICs) and virtual machines (VMs).
Collects metadata including subscription ID, NSG name, location, resource group, NIC name, and VM name.
Outputs results to an HTML report (nsgaudit_Report.html).
3. NSG-to-Subnet Association Audit (Scan_subnets_for_NSGs)
Iterates through all subscriptions and resource groups to identify virtual networks and their subnets.
Extracts NSG associations for each subnet.
Outputs results to an HTML report (Subnetsnsgaudit_Report.html).
4. NSG and Subnet Matching
Compares NSG assignments across NICs and subnets to identify overlaps and mismatches.
Outputs matched data to an HTML report (subnet_nsg_matches_Report.html).
5. Cleanup Operations
Remove NSG from Subnets: Disassociates NSGs from subnets where they are not actively used.
Delete Unused NSGs: Removes NSGs that are not associated with any NIC or VM.
Delete Orphaned NICs and NSGs: Identifies NICs with no associated VM and deletes both the NIC and its NSG.
Output
Three HTML reports for auditing:
nsgaudit_Report.html
Subnetsnsgaudit_Report.html
subnet_nsg_matches_Report.html
 
 
 #>
 

 $MaximumVariableCount = 16192
 $MaximumFunctionCount = 16192
  
connect-azaccount -Identity

  
  'microsoft.graph', 'Az.network'  | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
         #update-module $_ -force
           import-module -name $_ -force
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
        install-module -name $_ -allowclobber
        import-module -name $_ -force
    }
   #  Get-InstalledModule
}

######################################
  $connectedDevices = ''
  $results = ''

function Scan_NSGS
{

$query = @"
resources
| where type == "microsoft.network/networksecuritygroups"
| project nsgId = id, nsgName = name, location, resourceGroup, subscriptionId
| join kind=leftouter (
    resources
    | where type == "microsoft.network/networkinterfaces"
    | extend nsgId = tostring(properties.networkSecurityGroup.id),
             nicName = name,
             vmId = tostring(properties.virtualMachine.id),
             vmName = tostring(split(properties.virtualMachine.id, "/")[8])
    //| project nsgId, nicName, vmName
) on nsgId
| extend subscriptionId = tostring(subscriptionId)
| project subscriptionId, nsgName, location, resourceGroup, connectedNic = nicName, managingVm = vmName
| order by subscriptionId, nsgName asc
"@

$NSGScan = Search-AzGraph -Query $query
 

 
## ###########################################################

 foreach($nsg in $nsgscan)
 {
 
       $vmnicobj   = New-Object PSObject
  

        $vmnicobj | add-member -membertype noteproperty -name Subscriptionid -value $($nsg.Subscriptionid)
        $vmnicobj | add-member -membertype noteproperty -name NSGName -value $($nsg.NSGName)
        $vmnicobj | add-member -membertype noteproperty -name Location -value $($nsg.Location)
        $vmnicobj | add-member -membertype noteproperty -name Resourcegroup -value $($nsg.Resourcegroup)
        $vmnicobj | add-member -membertype noteproperty -name ConnectedNic -value $($nsg.ConnectedNic)
        $vmnicobj | add-member -membertype noteproperty -name managingVm -value $($nsg.managingVm)
       
        [array]$connectedDevices += $vmnicobj
    
  }

  $connectedDevices


############################################## 
#######  Generate HTML report

$CSS = @"
<Title>NSG Audit Report: $(Get-Date -Format 'dd MMMM yyyy') - Compliance Status</Title>
<Header>
<B>Company Confidential - NSG Audit Report: $(Get-Date -Format 'dd MMMM yyyy')</B> <br><I>Report generated from {3} on $env:computername {0} by {1}\{2} as a scheduled task</I><br><br>Please contact $contact with any questions "$(Get-Date -displayhint date)",$env:userdomain,$env:username
</Header>
<Style>
th {
    font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
    sans-serif;
    color: #FFFFFF;
    border-right: 1px solid #C1DAD7;
    border-bottom: 1px solid #C1DAD7;
    border-top: 1px solid #C1DAD7;
    letter-spacing: 2px;
    text-transform: uppercase;
    text-align: left;
    padding: 6px 6px 6px 12px;
    background: #5F9EA0;
}
td {
    font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
    sans-serif;
    border-right: 1px solid #C1DAD7;
    border-bottom: 1px solid #C1DAD7;
    background: #fff;
    padding: 6px 6px 6px 12px;
    color: #0000FF;
}
</Style>
"@

$nsgaudit_assignment_report = ($connectedDevices   | Sort-Object -Property SubscriptionId, ResourceGroupName, NSGName, ConnectedNic,managingVm  | ConvertTo-Html -Head $CSS)

$nsgaudit_assignment_report | Out-File c:\temp\nsgaudit_Report.html 
invoke-item  c:\temp\nsgaudit_Report.html

return $connecteddevices 

}


 #############################################################
 ### scan subnets for NSG associations

 function Scan_subnets_for_NSGs  
 {

 # Get all subscriptions
$subscriptions = Get-AzSubscription

# Initialize an array to store the results
$results = @()

# Iterate through each subscription
foreach ($subscription in $subscriptions) {
    # Set the context to the current subscription
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all resource groups in the subscription
    $resourceGroups = Get-AzResourceGroup

    # Iterate through each resource group
    foreach ($resourceGroup in $resourceGroups) {
        # Get all virtual networks in the resource group
        $virtualNetworks = Get-AzVirtualNetwork -ResourceGroupName $resourceGroup.ResourceGroupName

        # Iterate through each virtual network
        foreach ($virtualNetwork in $virtualNetworks) {
            # Get all subnets in the virtual network
            $subnets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $virtualNetwork

            # Iterate through each subnet
            foreach ($subnet in $subnets) {

            $subnet.NetworkSecurityGroup

                # Get the associated NSG, if any
                $nsgId = $($subnet.NetworkSecurityGroup.id)  

   
                $nsgresource = ($($nsgid) -split ('/'))[-1]
                         
                $nsgName = if ($nsgId) { (Get-AzNetworkSecurityGroup -Name  $nsgresource ) } else { "None" }

                # Add the result to the array
                $results += [PSCustomObject]@{
                    SubscriptionId    = $subscription.Id
                    ResourceGroupName = $resourceGroup.ResourceGroupName
                    VNetName          = $virtualNetwork.Name
                    SubnetName        = $subnet.Name
                    NSGName           = $nsgName.Name
                }
            }
        }
    }
    
$CSS = @"
<Title>Subnets with NSGs  Audit Report: $(Get-Date -Format 'dd MMMM yyyy') - Compliance Status</Title>
<Header>
<B>Company Confidential - NSG Audit Report: $(Get-Date -Format 'dd MMMM yyyy')</B> <br><I>Report generated from {3} on $env:computername {0} by {1}\{2} as a scheduled task</I><br><br>Please contact $contact with any questions "$(Get-Date -displayhint date)",$env:userdomain,$env:username
</Header>
<Style>
th {
    font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
    sans-serif;
    color: #FFFFFF;
    border-right: 1px solid #C1DAD7;
    border-bottom: 1px solid #C1DAD7;
    border-top: 1px solid #C1DAD7;
    letter-spacing: 2px;
    text-transform: uppercase;
    text-align: left;
    padding: 6px 6px 6px 12px;
    background: #5F9EA0;
}
td {
    font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
    sans-serif;
    border-right: 1px solid #C1DAD7;
    border-bottom: 1px solid #C1DAD7;
    background: #fff;
    padding: 6px 6px 6px 12px;
    color: #0000FF;
}
</Style>
"@

$Subnetsnsgaudit_assignment_report = ( $results | where resourcegroup -notlike '*asr*' | Sort-Object -Property SubscriptionId, ResourceGroupName, VNetName, NSGName, SubnetName  | ConvertTo-Html -Head $CSS)

$Subnetsnsgaudit_assignment_report | Out-File c:\temp\Subnetsnsgaudit_Report.html 
invoke-item  c:\temp\Subnetsnsgaudit_Report.html
}

# Output the results as a table
#$results | Format-Table -AutoSize

return  $results 
}
##################################
## get assignments and associations 

$nsgdevices = Scan_NSGS

$nsgsOnSubnets = Scan_subnets_for_NSGs 
################################
$matches = ''

$matches = foreach ($device in $nsgdevices)  {
    foreach ($subnet in ($nsgsOnSubnets| where-object { $_.DeviceRG -notlike '*asr*' -and $_.nsgname -notlike "*Bastion*" })) {
        if (
            $($device.SubscriptionId) -eq $($subnet.SubscriptionId) -and
            $($device.Resourcegroup) -eq $($subnet.ResourceGroupName) -and 
            $($device.NSGName) -eq $($subnet.NSGName) # -and $($device.ConnectedNic) -eq ''
        ) {
            [PSCustomObject]@{
                SubscriptionId    = $($device.SubscriptionId)
                NSGName           = $($device.NSGName)
                DeviceLocation    = $($device.Location)
                DeviceRG          = $($device.ResourceGroup)
                vnet              = $($subnet.VNetName)
                Subnet            = $($subnet.SubnetName)
                SubnetNSG         = $($subnet.NSGName)
                SubnetRG          = $($subnet.ResourceGroupName)
                ConnectedNic      = $($device.ConnectedNic)
                managingVm        = $($device.managingVm)
            }
        }
    }
}

# Output the matches
$matches | select -unique SubscriptionId, nsgname,Vnet,subnet, DeviceLocation,DeviceRG,SubnetRG,SubnetNSG, managingVm, ConnectedNic     | Format-Table -AutoSize

$subnet_nsg_matches = ($matches | select -unique SubscriptionId, nsgname, VNET, subnet,DeviceLocation,DeviceRG,SubnetRG,SubnetNSG, managingVm, ConnectedNic    | ConvertTo-Html -Head $CSS)

$subnet_nsg_matches | Out-File c:\temp\subnet_nsg_matches_Report.html 
invoke-item  c:\temp\subnet_nsg_matches_Report.html
#######################################


##############################################
###  Remove association of NSG to Subnets where NSG is not used


# Define parameters
 
foreach ($subnsg in ($matches | Where-Object  { $_.connectedNic -eq '' -and $_.managingVM -eq '' -and $_.DeviceRG -notlike '*asr*' -and $_.nsgname -notlike "*Bastion*"  })) {
    $sub = Get-AzSubscription -SubscriptionId $($subnsg.SubscriptionId)
    Set-AzContext -Subscription $($sub.Name)

    $vnet = Get-AzVirtualNetwork -Name $($subnsg.vnet) -ResourceGroupName $($subnsg.SubnetRG)

    # Find the subnet object in the VNet's subnet collection
    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnsg.subnet }

    if ($subnet -ne $null) {
        $subnet.NetworkSecurityGroup = $null

        # Replace the subnet in the VNet's subnet list
        $vnet.Subnets = $vnet.Subnets | ForEach-Object {
            if ($_.Name -eq $subnet.Name) { $subnet } else { $_ }
        }

        Set-AzVirtualNetwork -VirtualNetwork $vnet -Verbose
    } else {
        Write-Warning "Subnet $($subnsg.subnet) not found in VNet $($subnsg.vnet)"
    }
}


 
 
###################################

foreach ($emptyNSG in ($matches | where-object { $_.connectedNic -eq '' -and $_.managingVM -eq '' -and $_.DeviceRG -notlike '*asr*' -and $_.nsgname -notlike "*Bastion*" } ))
{
    $sub = get-azsubscription -subscriptionid $($emptyNSG.subscriptionid)
    set-azcontext -Subscription $($sub.Name)

    $NSGParams = @{
    Name              = "$($emptyNSG.NSGName)"
    ResourceGroupName = "$($emptyNSG.DeviceRG)"
}

# Remove the network security group
Remove-AzNetworkSecurityGroup @NSGParams -Force #-WhatIf


 
}


######################  
##check for orphaned NIc NSGs and deleted Nic first then NSG


foreach ($orphanedNSG in ($matches | where-object {  $_.connectedNic -ne '' -and $_.managingVM -eq '' -and $_.DeviceRG -notlike '*asr*' -and $_.nsgname -notlike "*Bastion*" } ))
{
    $sub = get-azsubscription -subscriptionid $($orphanedNSG.subscriptionid)
    set-azcontext -Subscription $($sub.Name)

   $orphanednics =   Get-azNetworkInterface  -ResourceGroupName $($orphanedNSG.resourcegroup)   -Name $($orphanedNSG.connectedNic) |`
      Remove-azNetworkInterface -Verbose -force  #-whatif 
 
    $ORPHANEDNSGParams = @{
    Name              = "$($orphanedNSG.NSGName)"
    ResourceGroupName = "$($orphanedNSG.DeviceRG)"
}

# Remove the network security group
Remove-AzNetworkSecurityGroup @ORPHANEDNSGParams -Force #-WhatIf
 
}


###################################
 

Scan_nsgs


