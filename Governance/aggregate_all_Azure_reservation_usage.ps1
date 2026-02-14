# Import the CSV file
$data = Import-Csv -Path "c:\temp\CostManagement_TreyResearchDemo.csv"

# Calculate the total cost for all data
$totalCostAll = ($data | Measure-Object -Property CostUSD -Sum).Sum

# Group the data by SubscriptionId, SKU, and ResourceType, and calculate the total cost and percentage of total cost
$aggregatedData = $data | Group-Object -Property subscriptioname, resourcegroupname,SKU, ResourceType,ReservationName | ForEach-Object {
    $totalCost = ($_.Group | Measure-Object -Property CostUSD -Sum).Sum
    [PSCustomObject]@{
        SubscriptionId = $_.Group.ResourceId -split '/' | Select-Object -Skip 2 -First 1
        SKU = $($_.Group.SKU) | select -first 1
        ResourceType = $($_.Group.ResourceType) | select -first 1
        ResourceGroupName = $($_.Group.ResourceGroupName) | select -first 1
        TotalCostUSD = $totalCost
        PercentageOfTotalCostUSD = "{0:N6}" -f [math]::Round(($totalCost / $totalCostAll) * 100, 6)
        Reservationname = $($_.group.ReservationName) | select -first 1
    }
} | Select-Object -Property SubscriptionId, ReservationName,SKU, ResourceType, ResourceGroupName, TotalCostUSD, PercentageOfTotalCostUSD -Unique

# Export the aggregated data to a new CSV file
#$aggregatedData

 

$CSS = @"

<Title>Azure Resource Usage  Warning  Report:$(Get-Date -Format 'dd MMMM yyyy') </Title>

 <H2>Azure Resource Usage Warning  Report:$(Get-Date -Format 'dd MMMM yyyy')  </H2>

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
	color: #6D929B;
}
</Style>


"@



########read in collected results and create the html report

$usagereport = $aggregatedData
 
 
$usage_report_detail = ((($usagereport   | Sort-Object -Property SubscriptionId, ReservationName,SKU, ResourceType, ResourceGroupName, TotalCostUSD, PercentageOfTotalCostUSD  |`
Select SubscriptionId, ReservationName,SKU, ResourceType, ResourceGroupName, TotalCostUSD, PercentageOfTotalCostUSD -Unique |`
ConvertTo-Html -Head $CSS ))) | Out-File "c:\temp\reservation_charge_percentage.html"
 

invoke-item "c:\temp\reservation_charge_percentage.html"
 












