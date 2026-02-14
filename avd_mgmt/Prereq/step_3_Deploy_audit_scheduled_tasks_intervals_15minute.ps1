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

 Param ($taskname, $taskpath,$taskdescription, $Username, $Password , $taskfolder, $tasksscript)
 $action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe' -argument "-ExecutionPolicy Bypass -windowstyle hidden  c:\programdata\jobs\$taskname"  
 
 $trigger =  New-ScheduledTaskTrigger -AtLogOn    
$pr = New-ScheduledTaskPrincipal  -Groupid  "INTERACTIVE" 
$trigger.Repetition = (New-ScheduledTaskTrigger -once -at "$timehour" -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -hours 24)).repetition

 Register-ScheduledTask  -Action $action -Trigger $trigger -TaskName  $taskname -Description "$taskdescription" -TaskPath $taskpath -RunLevel Highest  # -User "$UserName" -Password "$Password"  

}

 

Function Create-NewApplotTaskSettings

{

 Param ($taskname, $taskpath,$Username, $Password)

 $settings = New-ScheduledTaskSettingsSet -WakeToRun -Hidden   -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -RestartCount 3 -MultipleInstances Parallel

 Set-ScheduledTask -TaskName $taskname -Settings $settings -TaskPath $taskpath # -User "$UserName" -Password "$Password" 

}



### ENTRY POINT ###
#
#taskname = "applog"
 
$timespan = new-timespan -days 0 -hours 0 -minutes 1

 
$tasksfolder ="C:\programdata\Jobs\"
$tasksscripts = Get-ChildItem  $tasksfolder | select name,LastWriteTime #|where-object  {$_.LastWriteTime -gt ((get-date) - $timespan) }
$tasksscripts | convertto-csv | out-file c:\temp\tasks_scripts.csv

$tasklist = import-csv c:\temp\tasks_scripts.csv
foreach ($tasksscriptname in $tasklist)
{
$tasksscript = $tasksscriptname.Name
$tasksscript
 
$taskname = $tasksscript
$taskdescription = "AVD_Task_maintenance $taskscript"
$taskpath = "AVD_Maintenance"

If(Get-ScheduledTask -TaskName $taskname -EA 0)

  {Unregister-ScheduledTask -TaskName $taskname -Confirm:$false}

New-ScheduledTaskFolder -taskname $taskname -taskpath $taskpath  -taskfolder $taskfolder -taskscript $tasksscripts -Argument "$taskfolder$taskname" 

Create-AndRegisterApplogTask  -taskname $taskname -taskpath $taskpath -taskfolder $taskfolder -taskdescription $taskdescription -taskscript $tasksscripts -Username $Username -Password $Password -Argument "-ExecutionPolicy Bypass c:\programdata\jobs\$taskname" | Out-Null

Create-NewApplotTaskSettings -taskname $taskname -taskpath $taskpath -User  $Username -Password $Password   | Out-Null
}