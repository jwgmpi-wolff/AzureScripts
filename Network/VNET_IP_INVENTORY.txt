 
 
# Login to Azure
Connect-AzAccount

$subscriptions = get-azsubscription 

foreach($subscription in $subscriptions) 
{

# Select the subscription
Set-AzContext -SubscriptionId $($subscription.id)

# Get all virtual networks in the subscription
$vnetList = Get-AzVirtualNetwork

# Create an array to store the results
$results = ''
# Loop through each virtual network
foreach ($vnet in $vnetList)
 {

 $addressSpace = ''

    $vnetName = $($vnet.Name)
    $addressSpaces = $($vnet.AddressSpace.AddressPrefixes)
     
     foreach($addressspace in $addressspaces)
     {
        # Loop through each subnet in the virtual network
          foreach ($subnet in $vnet.Subnets) 
          {

          $subnetprefix  = Get-AzVirtualNetworkSubnetConfig  -Name $subnet.Name -VirtualNetwork $vnet | select addressprefix


            $subnetName = $($subnet.Name)
            $addressPrefixes =    $($subnetprefix.AddressPrefix)

            foreach($addressPrefix in $addressPrefixes) 
            {

                # Get the used IPs for the subnet
                $nicList = Get-AzNetworkInterface  | Where-Object { $_.IpConfigurations.Subnet.Id -eq $subnet.Id }
      
  
            foreach ($nic in $nicList)
             {

                $usedIps = $($nic.IpConfigurations.PrivateIpAddress)
            
                foreach($usedip in $usedips) 
                {
                # Add the results to the array
           
 


                    $ipObj = new-object PSobject 

                     $ipObj | Add-Member -MemberType NoteProperty -Name VNETNAME -Value $($VnetName)
                     $ipObj | Add-Member -MemberType NoteProperty -Name AddressSpace -Value  $($addressspace)
                     $ipObj | Add-Member -MemberType NoteProperty -Name SubnetName -Value $($SubnetName)
                     $ipObj | Add-Member -MemberType NoteProperty -Name AddressPrefix -Value $($AddressPrefix) 
                     $ipObj | Add-Member -MemberType NoteProperty -Name UsedIp -Value $($UsedIp)

                     [array]$results +=  $ipObj
                  }

                }
              }
            }
        }  
    }
 }


# Export the results to a CSV file
$results  | select Vnetname, AddressSpace, subnetname, addressprefix, usedip | Export-Csv -Path "C:\temp\vnets.csv" -NoTypeInformation







