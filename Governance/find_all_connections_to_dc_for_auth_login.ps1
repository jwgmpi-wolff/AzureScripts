$logons  = Get-WinEvent -LogName Security | Where-Object {
    $_.Id -eq 4624 -and $_.Properties[8].Value -eq "3"
} | Select-Object TimeCreated, machinename , @{Name="Source";Expression={$_.Properties[18].Value}}


$dcconnections = ''

foreach($connection in $logons )
{
    $logobj = new-object PSobject
   
 


     $connectedvm = nslookup $($connection.source)  
         $nameLine = $connectedvm | Select-String -Pattern "^Name\s*:\s*(.+)"
         $vmName = ($nameLine -split ":\s*")[1].Trim()


    $logobj | add-member -membertype noteproperty -name Timecreated -value $($connection.timecreated)

    $logobj | add-member -membertype noteproperty -name DCNAME -value $($connection.machinename)

    $logobj | add-member -membertype noteproperty -name IPAddress -value $($connection.source)

    $logobj | add-member -membertype noteproperty -name Vmname -value $vmName

    [array]$dcconnections += $logobj







}


#$logobj 
$dcconnections