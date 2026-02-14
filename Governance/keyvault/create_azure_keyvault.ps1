# Install the Azure PowerShell module (if not already installed)
#Install-Module -Name Az

# Connect to your Azure account
Connect-AzAccount

# Set the desired Azure subscription
Set-AzContext -SubscriptionId "wolffentpsub"
0
# Define the resource group and Key Vault name
$resourceGroupName = "wolffentpavdrg"
$keyVaultName = "wolffavdkeyvault"

# Create a new resource group (if it doesn't exist)
New-AzResourceGroup -Name $resourceGroupName -Location "westus"

# Create a new Key Vault
New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location "YourLocation"

# Display the Key Vault details
Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName
