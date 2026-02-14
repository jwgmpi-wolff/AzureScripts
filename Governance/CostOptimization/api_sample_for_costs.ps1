Install-Module -Name Az.Accounts
Install-Module -Name Az.Resources
#Then, you can use the following script to get cost allocations:

# Login to your Azure account
Connect-AzAccount -Identity
$subscriptions = get-azsubscription

# Select your subscription
foreach ($subscription in $subscriptions) 
{
    Select-AzSubscription -SubscriptionId $($subscription.Id)

    # Define the API version
    $apiVersion = '2024-01-01'

    # Define the start and end dates for the cost data
    $startDate = (Get-Date).AddMonths(-1).ToString('yyyy-MM-dd')
    $endDate = (Get-Date).ToString('yyyy-MM-dd')

    # Define the URL for the API call
    $url = "https://management.azure.com/subscriptions/$($subscription.Id)/providers/Microsoft.CostManagement/query?api-version=$apiVersion"

# Define the body of the API request
$body = @"
{
    "type": "ActualCost",
    "timeframe": "Custom",
    "timePeriod": {
        "from": "$startDate",
        "to": "$endDate"
    },
    "dataset": {
        "granularity": "Daily",
        "grouping": [
            { "type": "Dimension", "name": "ResourceGroupName" },
            { "type": "Dimension", "name": "ResourceLocation" },
            { "type": "Dimension", "name": "ServiceName" }
        ]
    }
}
"@

# Get an access token for the API call
    $accessToken = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token

    # Define the headers for the API call
    $headers = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer $accessToken"
    }

    # Call the API and get the response
    $response = Invoke-RestMethod -Method Post -Uri $url -Body $body -Headers $headers 

    # Output the cost data
    $response.properties.rows


}


