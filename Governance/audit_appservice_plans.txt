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

        Description:  The script generates a report about Azure App Service plans, including details like subscription, plan name, instance count, location, and tags.
        Prerequisites:
        You need to have Azure PowerShell installed.
        Ensure you are authenticated with your Azure account using connect-azaccount.
        Script Overview:
        The script iterates through all Azure tenants and subscriptions.
        For each subscription, it retrieves information about Azure App Service plans.
        It collects data such as subscription name, plan name, instance count, location, and tags.
        The collected data is organized into a summary report and a detailed report.
        Steps in the Script:
        Step 1: Define the function Invoke-OpenAISummarize with parameters for the API key, text to summarize, maximum tokens, and engine (e.g., ‘davinci’).
        Step 2: Set up the API connection details, including the URL and headers.
        Step 3: Construct the request body to specify the text to summarize.
        Step 4: Make the API request and return the summary.
        Running the Function:
        To use the function, provide your OpenAI API key and the text you want to summarize.
        Example usage:
        $summary = Invoke-OpenAISummarize -apiKey 'Your_Key' -textToSummarize 'Your text...'
        Write-Output "Summary: $summary"

        Replace 'Your_Key' with your actual API key and 'Your text...' with the text you want to summarize.
        The script generates two HTML reports:

        Detailed Report: Contains information about each Azure App Service plan, including subscription, plan name, instance count, location, and tags. The report is saved as Azureappserviceplan_report.html.
        Summary Report: Provides a concise summary of the data, including subscription, plan name, and instance count. The summary report is saved as Azureappserviceplan_summary_report.html.
             
         #>

connect-azaccount  -Environment AzureCloud -Tenant e594a530-1ec9-4192-a8d4-a9111f8cffa7
$ErrorActionPreference = 'silentlycontinue'
$appserviceplansdata = ''

$tenants = get-aztenant 
foreach($tenant in $tenants)
{
    $subscriptions = get-azsubscription -TenantId $($tenant.id)

        foreach($sub in $subscriptions)
        {
            set-azcontext -subscription $($sub.name)

           $rgs =  Get-AzResourceGroup 

         $appserviceplans = Get-AzAppServicePlan 
 

         if($appserviceplans)
         {
             foreach ($appinstance in $appserviceplans)
             {
             $appinstance | select name, kind
                 $Tags = $appinstance.Tags

                 IF ($null -eq $Tags )
                {
                     $Tagsvalue = 'Not taggable'
    
                } 
                Else
                {
                      $Tagsvalue = "$($tags.Keys)  + $($Tags.Values)"
                }
    


                 $appservice =  get-AzAppServicePlan -name $($appinstance.name) -ResourceGroupName $($rg.resourcegroupname)

                 $appserviceplanobj = new-object PSobject



                 $appserviceplanobj | add-member -MemberType NoteProperty -Name Subscription   -value $($sub.name) 
                 $appserviceplanobj | add-member -MemberType NoteProperty -Name Appserviceplan   -value $($appinstance.name)
                 $appserviceplanobj | add-member -MemberType NoteProperty -Name AppServiceinstance   -value $($appservice.Name)
                 $appserviceplanobj | add-member -MemberType NoteProperty -Name Resourcegroup   -value $($appinstance.ResourceGroup)
                 $appserviceplanobj | add-member -MemberType NoteProperty -Name Kind   -value $($appinstance.kind)
                 $appserviceplanobj | add-member -MemberType NoteProperty -Name Tags   -value "$Tagsvalue"
                 $appserviceplanobj | add-member -MemberType NoteProperty -Name Instancecount   -value $($appinstance.NumberOfSites)
                 $appserviceplanobj | add-member -MemberType NoteProperty -Name Location   -value $($appinstance.Location)
 
                [array]$appserviceplansdata += $appserviceplanobj


              }
          }
        }


    }

   $appserviceplansummary = $appserviceplansdata | where subscription -ne $null | select -Unique Subscription ,Appserviceplan, instancecount, location 

 $appserviceplanreport = $appserviceplansdata | select Subscription, Appserviceplan, AppServiceinstance, Resourcegroup, Kind, Tags, Instancecount, Location 





 
$CSS = @"
<Title>azure app service plan audi Report:$(Get-Date -Format 'dd MMMM yyyy' )</Title>
<Header>
 
"<B>Company Confidential</B> <br><I>Report generated from {3} on $env:computername {0} by {1}\{2} as a scheduled task</I><br><br>Please contact $contact with any questions "$(Get-Date -displayhint date)",$env:userdomain,$env:username
 </Header>

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






(($appserviceplanreport |  where subscription -ne $null  | select Subscription, Appserviceplan, AppServiceinstance, Resourcegroup, Kind, Tags, Instancecount, Location  | `
ConvertTo-Html -Head $CSS ) )      | Out-File c:\temp\Azureappserviceplan_report.html
 Invoke-Item c:\temp\Azureappserviceplan_report.html


 

(($appserviceplansummary |  where subscription -ne $null | select Subscription, Appserviceplan,  Instancecount  |`
ConvertTo-Html -Head $CSS ) )       | Out-File c:\temp\Azureappserviceplan_summary_report.html
 Invoke-Item c:\temp\Azureappserviceplan_summary_report.html















