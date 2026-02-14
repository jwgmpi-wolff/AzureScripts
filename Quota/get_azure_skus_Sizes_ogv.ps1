

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


 $DirectoryToCreate = 'C:\temp'

 if (-not (Test-Path -LiteralPath $DirectoryToCreate)) {
    
    try {
        New-Item -Path $DirectoryToCreate -ItemType Directory -ErrorAction Stop | Out-Null #-Force
    }
    catch {
        Write-Error -Message "Unable to create directory '$DirectoryToCreate'. Error was: $_" -ErrorAction Stop
    }
    "Successfully created directory '$DirectoryToCreate'."

}
else {
    "Directory already existed"
}
#> 
 
 ######################33
 ##  Necessary Modules to be imported.

import-module Az.Compute -force 
import-module az.marketplaceordering  -force
import-module Az.BareMetal -force 


 ############
 ## connect to Azure with authorized credentials 
 
 Connect-AzAccount # -Environment AzureUSGovernment

 


function get_subscriptions
{
          

				  
            $sub  = get-azsubscription | ogv -passthru | select subscriptionname, subscriptionID
            

             
                    $global:EnvironmentSubscriptionName = $sub.subscriptionname
                    $global:EnvironmentSubscriptionid =  $sub.subscriptionID

                        Select-azSubscription   -SubscriptionName $EnvironmentSubscriptionName -verbose
              #   set-azuresubscription -SubscriptionName $EnvironmentSubscriptionName

					set-azcontext -Subscription $($sub.subscriptionname)


				  Get-azSubscription  -Verbose  
				  
 
 

            # Present locations and allow user to choose location of their choice for Resource creation.
            #
}

#get_subscriptions

### PRep for skus completeness 

Get-AzResourceProvider -ListAvailable | where ProviderNamespace -eq 'microsoft.avs' |  Register-AzResourceProvider -verbose
Get-AzResourceProvider -ListAvailable | where ProviderNamespace -eq 'Microsoft.BareMetalInfrastructure' |  Register-AzResourceProvider -verbose


function get_locations
{
             $location =   Get-azLocation | ogv -PassThru | select displayname, location
  			 $resourceloc = $location.location
			
            Write-Host "Region successfully populated. All Resources will be created in the region: " $resourceloc -ForegroundColor Green
            return $resourceloc 
}
#

#$resourceloc = get_locations



  function get_skus([string] $resourceloc)
  {
		  #View the templates available
        
        $location= $($loc.Location)

 
        $vmSizes  =  Get-azVMSize -Location "$resourceloc" | select-object -Property * | ogv -passthru   | select * -first 1
        Return $vmsizes
  }


 
 
 $vmstoupdate = get-azvm | ogv -title " Select the VMs for sku changes: " -PassThru | Select * 


 foreach($vm in $vmstoupdate)
 {

           $VMSKUselected =  get_skus( $($vm.location) )  
            $VMSKUselected
 
        # Define parameters
        $resourceGroupName = "$($vm.ResourceGroupName)"
        $vmName = "$($vm.Name)"
        $newVmSize = "$($VMSKUselected.name)"



        # Stop the VM
       Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

        # Get the VM object
       $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

        # Change the VM size
        $vm.HardwareProfile.VmSize = $($VMSKUselected. )

        # Update the VM with the new size
        Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm

        # Start the VM
      Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

}














