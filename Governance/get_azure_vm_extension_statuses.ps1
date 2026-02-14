# Connect to Azure
Connect-AzAccount -Identity

# Get all virtual machines
$vms = Get-AzVM

# Create an array to store extension data
$extensionData = @()

# Loop through each virtual machine and get its extensions
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $resourceGroup = $vm.ResourceGroupName
    $extensions = Get-AzVMExtension -ResourceGroupName $resourceGroup -VMName $vmName -Status
    foreach ($extension in $extensions) {
        $extensionData += [PSCustomObject]@{
            VirtualMachine = $vmName
            ExtensionName = $extension.Name
            Publisher = $extension.Publisher
            Version = $extension.Version
            ProvisioningState = $extension.ProvisioningState
            Status = $extension.EnableAutomaticUpgrade

        }
    }
}

# Display the extension data in a table
$extensionData | Format-Table -AutoSize

 

Get-AzVMExtension -ResourceGroupName jwgovernance -VMName wolffmonvm-2 -Status



