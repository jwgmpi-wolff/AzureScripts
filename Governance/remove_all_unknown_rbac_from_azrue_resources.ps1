# Connect to your Azure account
Connect-AzAccount

# Define the scope (e.g., subscription, resource group, etc.)
$scope = "/"

# Get all role assignments with 'Unknown' ObjectType
$roleAssignments = Get-AzRoleAssignment -Scope $scope | Where-Object { $_.ObjectType -eq 'Unknown' }

# Remove each role assignment
foreach ($roleAssignment in $roleAssignments) {
     Remove-AzRoleAssignment -InputObject $roleassignment
}

Write-Output "Removed all 'Unknown' role assignments."
# This is the script but let me look for the link documentation