
$advisor_recs = import-csv "C:\temp\reservation_plan_from_advisor.csv" 
sl "C:\Users\jerrywolff\OneDrive - Microsoft\Documents\azure\PS1"



foreach($rec in $advisor_recs)
{

write-host "$($rec.recommendation)" -foregroundcolor cyan 


$response =  &  .\wolff_ai_foundry_call_HC_noreasoning_cleanonly.ps1  "provide a recommendation for $($rec.recommendation) "  *>&1
   
   
 
# 1) Decode HTML entities so &lt;/think&gt; becomes </think>
Add-Type -AssemblyName System.Web
$decoded = [System.Web.HttpUtility]::HtmlDecode($response )

# 2) Find the first closing </think> tag (case-insensitive), and extract everything after it
$pattern = '</think\s*>'            # allows optional whitespace before '>'
$match   = [System.Text.RegularExpressions.Regex]::Match($decoded, $pattern, 'IgnoreCase')

if ($match.Success) {
    $startIndex = $match.Index + $match.Length
    $afterThink = $decoded.Substring($startIndex)
    
    # 3) Trim leading/trailing whitespace
    $result = $afterThink.Trim()

    # 4) (Optional) Normalize Windows/Mac line endings
    $result = $result -replace "`r?`n", "`r`n"


    $resultobj = new-object PSObject 

   

   $resultobj | add-member -MemberType NoteProperty -name subscriptionname -value $($rec.subscriptionname)
   $resultobj | add-member -MemberType NoteProperty -name subscriptionId -value $($rec.subscriptionId)
   $resultobj | add-member -MemberType NoteProperty -name targetResourceCount -value $($rec.targetResourceCount)
   $resultobj | add-member -MemberType NoteProperty -name term -value $($rec.term)
   $resultobj | add-member -MemberType NoteProperty -name vmSize -value $($rec.vmSize)
   $resultobj | add-member -MemberType NoteProperty -name region -value $($rec.region)
   $resultobj | add-member -MemberType NoteProperty -name Recommendationname -value $($rec.Recommendationname)
   $resultobj | add-member -MemberType NoteProperty -name Recommendation -value $($rec.Recommendation)
   $resultobj | add-member -MemberType NoteProperty -name displaySKU -value $($rec.displaySKU)
   $resultobj | add-member -MemberType NoteProperty -name lookbackPeriod -value $($rec.lookbackPeriod)
   $resultobj | add-member -MemberType NoteProperty -name  RESULTGUIDANCE -value "$($result)"

   [array]$aLLRESULTS += $resultobj


    # Output the extracted portion
    #$result
}

}

##########


              
        # Generate HTML report
$date = Get-Date -Format 'dd MMMM yyyy'
$CSS = @"
<Title> Azure reservation instance Plan Forecast Report from Advisor: $date </Title>
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

$htmlContent = @"
<h2>Azure Reservations Forecast Report</h2>
<p>Date: $date</p>
<p>Azure reservation advisor with guidance: </p>
"@ + ( $aLLRESULTS | select subscriptionname,`
 subscriptionId,`
 targetResourceCount,`
 term,`
 vmSize,`
  region,`
 Recommendationname,`
 Recommendation,`
 displaySKU,`
 lookbackPeriod,`
  RESULTGUIDANCE| ConvertTo-Html -Head $CSS)

$outputHtmlPath = "c:\temp\guidancereservation_plan_from_advisor.html"
$htmlContent | Out-File -FilePath $outputHtmlPath

Write-Output "HTML report has been saved to $outputHtmlPath"

# Open the HTML report
Invoke-Item -Path $outputHtmlPath






