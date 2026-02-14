 
 
 $Subscriptions = Get-AzSubscription  #-SubscriptionName wolffentpsub


# Resolve subscriptions
$targetSubs = if ($Subscriptions -and $Subscriptions.Count -gt 0) {
    $Subscriptions | ForEach-Object {
        $sub = Get-AzSubscription -SubscriptionId $_ -ErrorAction SilentlyContinue
        if (-not $sub) { $sub = Get-AzSubscription -SubscriptionName $_ -ErrorAction SilentlyContinue }
        if ($sub) { $sub } else { Write-Warning "Subscription '$_' not found."; $null }
    } | Where-Object { $_ -ne $null }
} else {
    @(Get-AzContext).Subscription
}

if (-not $targetSubs -or $targetSubs.Count -eq 0) {
    throw "No valid subscriptions to search."
}
 
 
 
$results = ''

foreach ($sub in $targetSubs) {
    Write-Host "Searching subscription: $($sub.Name) ($($sub.Id))" -ForegroundColor Cyan
    Set-AzContext -Subscription $sub.Id | Out-Null

 

    # Find Query Packs (resource type: Microsoft.OperationalInsights/queryPacks)
    $queryPacks = Get-AzResource -ResourceType "Microsoft.OperationalInsights/queryPacks" -ErrorAction SilentlyContinue

    if ($ResourceGroups -and $ResourceGroups.Count -gt 0) {
        $queryPacks = $queryPacks | Where-Object { $ResourceGroups -contains $_.ResourceGroupName }
    }

    foreach ($qp in $queryPacks) {
        Write-Host "  Query Pack: $($qp.Name)  RG: $($qp.ResourceGroupName)" -ForegroundColor Yellow

        $apiVersion = "2025-07-01"
        $qp = Get-AzResource -ResourceType "Microsoft.OperationalInsights/queryPacks" -ResourceGroupName "$($qp.resourcegroupname)" -Name "$($qp.name)"
      
        $resp = Invoke-AzRestMethod -Method GET -Path "$($qp.ResourceId)/queries?api-version=$apiVersion" |
          Select -ExpandProperty Content
           $resp 

 
    

        $body = $resp | ConvertFrom-Json
        $items = @()
        if ($body.value) { $items = $body.value } elseif ($body.properties) { $items = @($body) } # safety

        foreach ($item in $items) {
            # ARM shape: id, name, type, properties.{displayName, description, body, related{categories,resourceTypes,solutions}, tags}
            $p = $item.properties

                $resultsobj = new-object psobject

                $resultsobj | add-member -MemberType NoteProperty -name   SubscriptionId    -value  $sub.Id 
                $resultsobj | add-member -MemberType NoteProperty -name    SubscriptionName  -value  $sub.Name
                $resultsobj | add-member -MemberType NoteProperty -name  ResourceGroup     -value  $qp.ResourceGroupName
                $resultsobj | add-member -MemberType NoteProperty -name  QueryPackName     -value  $qp.Name
                $resultsobj | add-member -MemberType NoteProperty -name  QueryId           -value  $item.name
                $resultsobj | add-member -MemberType NoteProperty -name  DisplayName       -value  $p.displayName
                $resultsobj | add-member -MemberType NoteProperty -name   Description       -value  $p.description 
                $resultsobj | add-member -MemberType NoteProperty -name  Categories        -value  ($p.related.categories -join ", ")
                $resultsobj | add-member -MemberType NoteProperty -name  ResourceTypes     -value  ($p.related.resourceTypes -join ", ")
                $resultsobj | add-member -MemberType NoteProperty -name  Solutions         -value  ($p.related.solutions -join ", ")
  
                $resultsobj | add-member -MemberType NoteProperty -name QueryBody         -value  $p.body
 
 
               [array]$results += $resultsobj  
            
        }
    }
}


$results


if ($OutputJson) {
    $results | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputJson -Encoding UTF8
    Write-Host "Wrote matched queries to: $OutputJson" -ForegroundColor Green
}

# Present concise table
$results |
    Select-Object SubscriptionId, SubscriptionName, ResourceGroup, QueryPackName, QueryId, DisplayName, Description, Categories, ResourceTypes, Solutions ,Querybody |
    Sort-Object SubscriptionName, ResourceGroup, QueryPackName, DisplayName |
    export-Csv c:\temp\azure_querypack_queries.csv -NoTypeInformation

Write-Host "`nTotal matches: $($results.Count)`n"
