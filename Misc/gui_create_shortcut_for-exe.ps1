FUNCTION CREATE_EXE_SHORTCUT
{


   [CmdletBinding()]
    param(
    # The file
    [Parameter(Mandatory=$true, Position=0,ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname')]
    [string]$File,
    
    
    # If provided, will output the icon to a location
    [Parameter(Position=1, ValueFromPipelineByPropertyName=$true)]
    [string]$OutputFile,
    
 
   # If provided, will output the icon to a location
    [Parameter(Position=1, ValueFromPipelineByPropertyName=$true)]
    [string]$iconfile
    )

    $Shell = New-Object -ComObject ("WScript.Shell")
    $ShortCut = $Shell.CreateShortcut("$OutputFile.lnk")
    $ShortCut.TargetPath="$FILE"
    #$ShortCut.Arguments="-arguementsifrequired"
    $ShortCut.WorkingDirectory = "$env:USERPROFILE\Desktop";
    $ShortCut.WindowStyle = 1;
    $ShortCut.Hotkey = "CTRL+SHIFT+F";
    $ShortCut.IconLocation = "$iconfile, 0";
    $ShortCut.Description = "$outputfile";

    $ShortCut.save()



}
 

Function Create_tempfolder
{
    if   ( !(  Test-Path  -path 'c:\temp')) {
    New-Item -ItemType Directory -path 'C:\temp' -verbose
   # write-host " Temp folder created " -ForegroundColor Green -BackgroundColor Black
    }


} 
 
create_tempfolder
 

function Get-FileName($InitialDirectory)
{
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
     # Define Title
    $OpenFileDialog.Title = "Select Source executable"
    $OpenFileDialog.InitialDirectory = $InitialDirectory
    $OpenFileDialog.filter = "images (*.exe) |*.exe|(*.com)|*.com"
    $OpenFileDialog.ShowDialog(((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))) | Out-Null
    $OpenFileDialog.FileName
 
    
}

Function Get-Folder($initialDirectory)
{
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = 'Select the icon folder destination'
    $result = $FolderBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK){
    $FolderBrowser.SelectedPath
    } else {
    exit
    }
}

function Get-icon($InitialDirectory)
{
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
     # Define Title
    $OpenFileDialog.Title = "Select icon to use"
    $OpenFileDialog.InitialDirectory = $InitialDirectory
    $OpenFileDialog.filter = "images (*.ico) |*.ico"
    $OpenFileDialog.ShowDialog(((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))) | Out-Null
    $OpenFileDialog.FileName
 
    
}


$sourceimagefile = Get-FileName('c:\')

$targetfilename =  [System.IO.Path]::GetFileNameWithoutExtension("$sourceimagefile")


$targetfolder =  Get-Folder('c:\')
 
$iconfile = Get-icon ('c:\')

CREATE_EXE_SHORTCUT -File $sourceimagefile -OutputFile $targetfolder\$targetfilename.ico -iconfile $iconfile 

