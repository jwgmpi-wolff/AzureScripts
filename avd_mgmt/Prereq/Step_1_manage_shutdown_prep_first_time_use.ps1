###########################   Azure and powershell Packages and modules setup 


 'az', 'Az.DesktopVirtualization' ,'ps2exe', 'nuget'| foreach-object {


  if((Get-InstalledModule -name $_ ) | out-null)
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
 
}

    Get-InstalledModule

#####################################################


    $jobs = 'c:\programdata\jobs'

   if (-not (Test-path   $jobs))
   {
        New-Item  $jobs  -Type Directory
 
   }
       $avd_tools = 'c:\programdata\avd_tools'

   if (-not (Test-path   $avd_tools))
   {
        New-Item  $avd_tools  -Type Directory
 
   }



#############################  setup Even viewer source 

New-EventLog -source manage_shutdown_monitor  -LogName Application  -ErrorAction Ignore



#################################  Event Viewer_setup Setup  ##############
## Setup warning event 6667
  Write-EventLog -LogName "Application" -Source "Manage_shutdown_monitor" -EventID 6667 -EntryType Information `
                    -Message "initial setup for 15 minute warning event:  $timecheck " -Category 1 -RawData 10,20

#################################  Registry Setup  ##############
 $timecheck = (get-date)
 $timecheckinitial = (get-date).AddDays(365)
 $date = (get-date)

            # create  the registry key to indicate when the script is shutting down the VM
             try
             {
                $manage_shutdownreg = Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -erroraction Ignore| out-null
                if(!($manage_shutdownreg))
                {

                  New-Item -Path "HKLM:\Software" -Name "MANAGE_SHUTDOWN" -Force | out-null
                }
             }
             catch
             {
               New-Item -Path "HKLM:\Software" -Name "MANAGE_SHUTDOWN" -Force | out-null
             }

  
                  
                         $Timeleft =  New-TimeSpan -Start $timecheck -End $($timecheckinitial)  
                         $daysleft  = New-TimeSpan -Start $timecheck -End $($timecheckinitial) | select days 
                         $hoursleft = New-TimeSpan -Start $timecheck -End $($timecheckinitial) | select  hours 
                         $minutesleft = New-TimeSpan -Start $timecheck -End $($timecheckinitial) | select  minutes
                         $resettimetostop = ($date).AddMonths(12)


                #############  Setup registry entries
                
                
                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart" -Value ""  -Force  | Out-Null

                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timetostop" -Value "$resettimetostop" -Force  | Out-Null

                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timecheck" -Value "$timecheck" -Force  | Out-Null
                
                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timeleft" -Value "$Timeleft" -Force  | Out-Null

                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "GraceTime" -Value "" -Force  | Out-Null


                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Daysleft" -Value "$($Daysleft.Days)" -Force  | Out-Null

                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Hoursleft" -Value "$($hoursleft.Hours)" -Force  | Out-Null                                                        

                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Minutesleft" -Value "$($Minutesleft.Minutes)" -Force  | Out-Null


                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timetostopset" -Value "NO" -Force | Out-Null


                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Timetostopsetdate" -Value "$timecheck" -Force  | Out-Null

                            New-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Resettime" -Value "Yes" -Force  | Out-Null



##########################  Update blank registry keys

                        try{
                            
                            if((Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "gracetime") -ne '') 
                                {
                                 $gracetime = Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "gracetime"

                                [datetime]$gracetimeset = (get-date -date $($gracetime.Gracetime) )

                                
                                Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "Initialstart" -Value "$date" -Force | Out-Null

                                 $initialstart = Get-ItemProperty -Path  "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "InitialStart"

                                 [datetime]$initialstartedate = get-date -date $($initialstart.InitialStart)

                   
                   
                                $gracetime = (get-date -date $initialstartedate).AddMinutes(+15)
         
                                  Set-ItemProperty -Path "HKLM:\SOFTWARE\MANAGE_SHUTDOWN" -Name "GraceTime" -Value "$gracetime" -Force | Out-Null
 
                                }
                            }

                        catch
                        {
                            write-warning " New installation - Gracetime not yet set" 

                        }
                       




             
##############################
 
$path = Split-Path $psISE.CurrentFile.FullPath 

sl $path

get-childitem -Path ..\ -Recurse |  copy-item -Destination "c:\programdata\avd_tools\" -Recurse -force
 
get-childitem -Path  ..\jobs\  -File "MANAGE_SHUTDOWN_TimeBased_gui.ps1" | copy-item -Destination "c:\programdata\jobs\"  -force



  get-childitem -Path "C:\programdata\avd_tools\"
  get-childitem -Path "C:\programdata\jobs\"



###############
