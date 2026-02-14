<#
Scriptname: \MANAGE_SHUTDOWN_TimeBase_monitor.ps1

the script reads a registry key and monitor for a time set by the user to shutdown 


Description: 
    Script is typically storad in c:\prgramdata\jobs folder and is 
    added to the scheduled task manager under the folder AVD_maintenance
    
    Script is deployed using Deploy_audit_scheduled_tasks_intervals_15Minute_Azvault.PS1 accompnaying this 
    script or can be added manually in the task scheduler. 
    
     
script will read registry entry created by MANAGE_SHUTDOWN_TimeBased_set.ps1 run to set the time for the VM to shutdown 


              "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timetostop" -Value "$($timetostop)" 
              "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timecheck" -Value " $timecheck"  
              "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timeleft" -Value "$hoursleft" 


        Once the current time reaches the time set to shutdown 
        this script will ready the creadential from the AZ keyvault for the service principal/managed Identity
        with permissions to execute the shutdown and deallocation
        and execute an Azure Clean shutdown and deallocation 

        This script will ready the registry keys with the tmmestamp every 15 minutes to see if it has reached its time.


  'az', 'Az.DesktopVirtualization' | foreach-object {


  if((Get-InstalledModule -name $_))
  { 
    Write-Host " Module $_ exists  - updating" -ForegroundColor Green
       #  update-module $_ -force
    }
    else
    {
    write-host "module $_ does not exist - installing" -ForegroundColor red -BackgroundColor white
     
       & install-module -name $_ -allowclobber -force | out-null
      
    }
         &   import-module -name $_ -force | out-null
   #  Get-InstalledModule
}
  
           

#>

#######>
$ErrorActionPreference = 'silentlycontinue'


  Add-Type -AssemblyName System.Windows.Forms
 
$vmName = "$env:computername"





 
#############################
 $account = connect-azaccount     -id  | out-null  #-Environment AzureUSGovernment 

 $sub = get-azsubscription -SubscriptionName $($account.Context.Subscription.Name)  

$context =  set-azcontext -Subscription $($sub.Name) | out-null

 

################################

New-EventLog -source manage_shutdown_monitor  -LogName Application  -ErrorAction Ignore  | out-null



########################
 $vminfo = get-azvm -name $VMNAME

$resourceGroup = "$($vminfo.ResourceGroupName)"
$location =  "$($vminfo.Location)"


#####################################################################


$date = (get-date)

############################################################################

Function update_grace_time
{


$configured_time  =  Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart", "Timetostop","Timecheck","Timeleft","Timetostopset", "Timetostopsetdate", "GraceTime", "Daysleft","Hoursleft","Minutesleft" 
 

         $gracetime = Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "gracetime"

        [datetime]$gracetimeset = (get-date -date $($gracetime.Gracetime) )
         
 
}


############################################################################


$configured_time  =  Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart", "Timetostop","Timecheck","Timeleft","Timetostopset", "Timetostopsetdate", "GraceTime", "Daysleft","Hoursleft","Minutesleft" 
 
 if($($configured_time.initialstart) -eq '')
 {

          Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Initialstart" -Value $date -Force | Out-Null

         $initialstart = (Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart").initialstart 
         [datetime]$initialstartedate = get-date -date $($initialstart)

        $gracetime = (get-date -date $initialstartedate).AddMinutes(+15)
         
          Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "GraceTime" -Value "$gracetime" -Force | Out-Null
 }


$Timetostopset =  $($configured_time.Timetostopset)

##################### Set a marker for the first login message initial login plus 15 minutes grace time 


 [datetime]$initialStart = get-date -date $($configured_time.InitialStart)

[datetime]$firstmessagetime = (get-date -date $initialStart).AddMinutes(+15)


####################################   Check to see if a timetostop is set and set a marker for warning  for actual shutdow after a timetostop is set 

 

 if($($configured_time.timetostopset) -eq 'Yes')
 {
        [datetime]$timetostop = $($configured_time.timetostop)

     $remainingtime = (get-date -date $timetostop).AddMinutes(-15)

    }
    else
    {
        [datetime]$timetostop = $($configured_time.Timetostop)

    }

################################################################################ status check session for when the first timetostop time has been set and track 
 
            $timecheck = (get-date)

############################################################################

             $firstmessagetimeLeft = New-TimeSpan -Start (Get-Date) -End $firstmessagetime


if(($($configured_time.Timetostopset) -eq 'NO')-and (get-date) -lt $gracetime)
{
                 If( ((get-date) -ge $firstmessagetime) -and ($($configured_time.Timetostopset) -eq 'NO') )
                 {
                     Write-EventLog -LogName "Application" -Source "Manage_shutdown_monitor" -EventID 6667 -EntryType Information `
                    -Message "Grace time has ended $timecheck with  Timeleft $firstmessagetimeLeft - please set a targeted shutdown time - this can be changed if needed " -Category 1 -RawData 10,20
 
                 } 
                 else
                 {
                     
                 
                    Write-EventLog -LogName "Application" -Source "Manage_shutdown_monitor" -EventID 6665 -EntryType Information `
                    -Message "initial start checking every 1 minute from $timecheck  unitl $firstmessagetime has been reached  Timeleft: $firstmessagetimeLeft " -Category 1 -RawData 10,20

                
                     [datetime]$initaltimewaiting = get-date -date   $($firstmessagetime)

                     
                    $hoursminutesleft = "$($firstmessagetimeLeft.hours):$($firstmessagetimeLeft.minutes)"


                
                             $daysleft  = New-TimeSpan -Start $timecheck -End $initaltimewaiting | select days 
                             $hoursleft = New-TimeSpan -Start $timecheck -End $initaltimewaiting | select  hours 
                             $minutesleft = New-TimeSpan -Start $timecheck -End $initaltimewaiting | select  minutes

    

                 # Update the registry key to indicate that the script is shutting down the VM
 
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timecheck" -Value "$timecheck" -Force | Out-Null
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timeleft" -Value "$firstmessagetimeLeft" -Force | Out-Null

                    Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timetostop" -Value "$($configured_time.TimetoStop)" -Force | Out-Null
 

                    Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Daysleft" -Value "$($Daysleft.Days)" -Force  | Out-Null

                    Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Hoursleft" -Value "$($hoursleft.Hours)" -Force  | Out-Null                                                        

                    Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Minutesleft" -Value "$($Minutesleft.Minutes)" -Force  | Out-Null

                   set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Resettime" -Value "$($Configured_time.Resettime)" -Force  | Out-Null

                # Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart", "Timetostop","Timecheck","Timeleft","Timetostopset", "Timetostopsetdate" , "GraceTime",  "Daysleft","Hoursleft","Minutesleft" 
                  

                  }
    }
       
  #########################################################################

  $finalminutes = New-TimeSpan -Start (get-date) -End   $timetostop
  
if(($($configured_time.Timetostopset) -eq 'Yes') -and $date -ge ($timetostop).addminutes(-15) )
{
  
    
             Write-EventLog -LogName "Application" -Source "Manage_shutdown_monitor" -EventID 6667 -EntryType Information `
             -Message "Grace time has ended $timecheck with  Timeleft: $finalminutes  - please set a targeted shutdown time - this can be changed if needed " -Category 1 -RawData 10,20
      
  
  
  }
  
  
  ##############################################################################     
       
       
       
               
    ########################## Warning message section 

                ###### If a shutdown time is set check for remaining time before warning message is triggered 

             if (((Get-Date) -ge $remainingtime) -and ($($Timetostopset) -eq 'Yes')) 
             {

 

                 Write-EventLog -LogName "Application" -Source "Manage_shutdown_monitor" -EventID 6668 -EntryType Information `
                    -Message "Warning period has been reached - VM Will be triggered for shutdown --  $timecheck " -Category 1 -RawData 10,20

                

            }
         

 
 
         ########################################## Update Registry section 

                
            $configured_time  =  Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart", "Timetostop","Timecheck","Timeleft","Timetostopset", "Timetostopsetdate" , "GraceTime",  "Daysleft","Hoursleft","Minutesleft" 
  
 

            if($configured_time.Timetostopset -eq 'Yes' )
            {
                  [datetime]$Timetostop = get-date -date   $($configured_time.Timetostop)

               $Timeleft =  New-TimeSpan -Start $timecheck -End $Timetostop 

                [datetime]$Timetostop = get-date -date   $($configured_time.Timetostop)
 

                $hoursminutesleft = "$($Timeleft.hours):$($Timeleft.minutes)"


                
                         $daysleft  = New-TimeSpan -Start $timecheck -End $Timetostop | select days 
                         $hoursleft = New-TimeSpan -Start $timecheck -End $Timetostop | select  hours 
                         $minutesleft = New-TimeSpan -Start $timecheck -End $Timetostop | select  minutes

 
                
                Write-EventLog -LogName "Application" -Source "Manage_shutdown_monitor" -EventID 6666 -EntryType Information `
                 -Message "$timetostop -  Time left: $timeleft to :  $timecheck.  Settings; $configured_time" -Category 1  
            

             # Update the registry key to indicate that the script is shutting down the VM
 
                Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timecheck" -Value " $timecheck" -Force | Out-Null
                Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timeleft" -Value "$Timeleft" -Force | Out-Null

                Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timetostop" -Value "$Timetostop " -Force | Out-Null
 

                Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Daysleft" -Value "$($Daysleft.Days)" -Force  | Out-Null

                Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Hoursleft" -Value "$($hoursleft.Hours)" -Force  | Out-Null                                                        

                Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Minutesleft" -Value "$($Minutesleft.Minutes)" -Force  | Out-Null


             #   Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart", "Timetostop","Timecheck","Timeleft","Timetostopset", "Timetostopsetdate" , "GraceTime",  "Daysleft","Hoursleft","Minutesleft" 
 
    
                   if($Timetostop  -ge  (get-date))
                   {
 
                          update_grace_time

                  }


 
             }
 






