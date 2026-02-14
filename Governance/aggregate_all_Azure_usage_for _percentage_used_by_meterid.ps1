 
# Import the CSV file
$data = Import-Csv -Path "c:\temp\allusage.csv"


# Calculate the total quantity for all data
$totalQuantityAll = ($data | Measure-Object -Property Quantity -Sum).Sum

# Group the data by SubscriptionId, MeterId, and MeterName, and calculate the total quantity and percentage of total quantity
$aggregatedData = $data | group-Object -Property SubscriptionId, MeterId, MeterName | ForEach-Object {
    $totalQuantity = ($_.Group | Measure-Object -Property Quantity -Sum).Sum
        $resourceGroup = ($_.Group | Select-Object -First 1).InstanceData | ConvertFrom-Json | ForEach-Object { $_."Microsoft.Resources".resourceUri -split '/' | Select-Object -Skip 4 -First 1 }
    [PSCustomObject]@{
        SubscriptionId = $($_.Group.SubscriptionId) | select -first 1
        MeterId = $($_.Group.MeterId)  | select -first 1
        MeterName = $($_.Group.MeterName) | select -first 1
        MeterSubCategory = $($_.Group.MeterSubCategory) | select -first 1
        ResourceGroup = $resourceGroup -replace 'resourceGroups/', ''
        TotalQuantity = $totalQuantity
        PercentageOfTotalQuantity = "{0:N6}" -f [math]::Round(($totalQuantity / $totalQuantityAll) * 100, 6)
    }
} | Select-Object -Property SubscriptionId, MeterId, MeterName, MeterSubCategory, ResourceGroup, TotalQuantity, PercentageOfTotalQuantity -Unique

# Export the aggregated data to a new CSV file
$aggregatedData 

