#####################################################################
## SCript name: Deploy_audit_scheduled_tasks_intervals
## Created by: Jerry Wolff
## create Date: 4/1/2015
## Modified Date:
## Description: Script to read a list of scripts from a jobs folder
##   and create scheduled tasks for ENIAT - Deploy scripts from c:\programdata\jobs
#####################################################################
 


Function Create_tempfolder
{
    if   ( !(  Test-Path  -path 'c:\temp')) {
    New-Item -ItemType Directory -path 'C:\temp' -verbose
    write-host " Temp folder created " -ForegroundColor Green -BackgroundColor Black
    }


} 


create_tempfolder


# Get the credentials #
  $creds = Get-Credential
 $UserName = $creds.UserName
 $Password = $creds.GetNetworkCredential().Password
 

function check_jobs_folder
{

    if   ( !(  Test-Path  -path 'C:\ProgramData\Jobs')) {
    write-warning " C:\ProgramData\Jobs folder does not exist or is not accessible - nothing to create task with" 
  
 exit 1
    } 
     

}
check_jobs_folder

 
 # Get the credentials #
  $creds = Get-Credential
 $UserName = $creds.UserName
 $Password = $creds.GetNetworkCredential().Password
 

 $eventid = 6667

Function New-ScheduledTaskFolder

    {

     Param ($taskpath)

     $ErrorActionPreference = "stop"

     $scheduleObject = New-Object -ComObject schedule.service

     $scheduleObject.connect()

     $rootFolder = $scheduleObject.GetFolder("\")

        Try {$null = $scheduleObject.GetFolder($taskpath)}

        Catch { $null = $rootFolder.CreateFolder($taskpath) }

        Finally { $ErrorActionPreference = "continue" } }

      $timehour = Get-Date -format "HH tt"


Function Create-AndRegisterApplogTask
{

 Param ($eventid,$taskname, $taskpath,$taskdescription,$Username, $Password ,$taskfolder, $tasksscript)

 $action = New-ScheduledTaskAction -Execute "c:\programdata\avd_tools\$tasksscript" -WorkingDirectory "C:\programdata\avd_tools\"
 
 $trigger =  New-ScheduledTaskTrigger -AtLogOn    #-User $env:username
 
$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger

$Trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly

$pr = New-ScheduledTaskPrincipal  -Groupid  "INTERACTIVE" 

$Trigger.Subscription = 
@"
<QueryList><Query Id="6667" Path="System"><Select Path="Application">*[System[Provider[@Name='Manage_shutdown_monitor'] and EventID=6667]]</Select></Query></QueryList>
"@
$Trigger.Enabled = $True 

 Register-ScheduledTask  -Action $action -Trigger $trigger -TaskName  $taskname -Description "$taskdescription" -TaskPath $taskpath -RunLevel Highest  #  -User "$UserName" -Password "$Password"  

}

 
# On an event; On event - Log: Application, Source: Manage_shutdown_monitor, Event ID: 6667

Function Create-NewApplotTaskSettings

{

 Param ($taskname, $taskpath, $action  ,$Username, $Password)

 $settings = New-ScheduledTaskSettingsSet -WakeToRun -Hidden   -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -RestartCount 3 -MultipleInstances IgnoreNew

 Set-ScheduledTask   -TaskName $taskname -Settings $settings -TaskPath $taskpath  #  -User "$UserName" -Password "$Password" 

}



### ENTRY POINT ###
#
#taskname = "applog"
 
$timespan = new-timespan -days 0 -hours 0 -minutes 5

 
$tasksfolder ="C:\programdata\avd_tools\"
$tasksscripts = Get-ChildItem  $tasksfolder | select name,LastWriteTime  | where-object  {$_.Name -eq "shutdown_reminder.exe" -or $_.name -eq 'countdown_clock.exe' }
$tasksscripts | convertto-csv | out-file c:\temp\tasks_scripts.csv

$tasklist = import-csv c:\temp\tasks_scripts.csv
foreach ($tasksscriptname in $tasklist)
{
$tasksscript = $tasksscriptname.Name
$tasksscript
 
$taskname = $tasksscript
$taskdescription = "Event_Viewer_tasks $taskscript"
$taskpath = "Event Viewer tasks"

If(Get-ScheduledTask -TaskName $taskname -EA 0)

  {Unregister-ScheduledTask -TaskName $taskname -Confirm:$false}

New-ScheduledTaskFolder -taskname $taskname -taskpath $taskpath  -taskfolder $taskfolder -taskscript $tasksscripts -Argument "$taskfolder$taskname" 

Create-AndRegisterApplogTask  -taskname $taskname -taskpath $taskpath -taskfolder $taskfolder -taskdescription $taskdescription -tasksscript $($tasksscriptname.Name)  -Username $Username -Password $Password  -Argument "-ExecutionPolicy Bypass c:\programdata\jobs\$taskname" | Out-Null

Create-NewApplotTaskSettings -taskname $taskname -taskpath $taskpath -User  $Username -Password $Password   | Out-Null
}





















