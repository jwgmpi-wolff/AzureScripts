
Add-Type -AssemblyName System.Windows.Forms

###https://www.powershellgallery.com/packages/ps2exe/1.0.12
###Install-Module -Name ps2exe -allowclobber -force

function ConvertTo-Icon
{
    <#
    .Synopsis
        Converts image to icons
    .Description
        Converts an image to an icon
    .Example
        ConvertTo-Icon -File .\Logo.png -OutputFile .\Favicon.ico
    #>
    [CmdletBinding()]
    param(
    # The file
    [Parameter(Mandatory=$true, Position=0,ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname')]
    [string]$File,
    
    # If set, will output bytes instead of creating a file
    [switch]$InMemory,
    
    # If provided, will output the icon to a location
    [Parameter(Position=1, ValueFromPipelineByPropertyName=$true)]
    [string]$OutputFile
    )
    
    begin {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        
    }
    
    process {
        #region Load Icon
        $resolvedFile = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($file)
        if (-not $resolvedFile) { return }
        $loadedImage = [Drawing.Image]::FromFile($resolvedFile)
        $intPtr = New-Object IntPtr
        $thumbnail = $loadedImage.GetThumbnailImage(72, 72, $null, $intPtr)
        $bitmap = New-Object Drawing.Bitmap $thumbnail 
        $bitmap.SetResolution(72, 72); 
        $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon());         
        #endregion Load Icon

        #region Save Icon
        if ($InMemory) {                        
            $memStream = New-Object IO.MemoryStream
            $icon.Save($memStream) 
            $memStream.Seek(0,0)
            $bytes = New-Object Byte[] $memStream.Length
            $memStream.Read($bytes, 0, $memStream.Length)                        
            $bytes
        } elseif ($OutputFile) {
            $resolvedOutputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputFile)
            $fileStream = [IO.File]::Create("$resolvedOutputFile")                               
            $icon.Save($fileStream) 
            $fileStream.Close()               
        }
        #endregion Save Icon

        #region Cleanup
        $icon.Dispose()
        $bitmap.Dispose()
        #endregion Cleanup

    }
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
    $OpenFileDialog.Title = "Select Source Images"
    $OpenFileDialog.InitialDirectory = $InitialDirectory
    $OpenFileDialog.filter = "images (*.png) |*.png|(*.jpg)|*.jpg"
    $OpenFileDialog.ShowDialog(((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))) | Out-Null
    $OpenFileDialog.FileName
 
    
}

Function Get-Folder($initialDirectory)
{
    Add-Type -AssemblyName System.Windows.Forms
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = 'Select the folder destination'
    $result = $FolderBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK){
    $FolderBrowser.SelectedPath
    } else {
    exit
    }
}

$sourceimagefile = Get-FileName('c:\')

$targetfilename =  [System.IO.Path]::GetFileNameWithoutExtension("$sourceimagefile")


$targetfolder =  Get-Folder('c:\')
 


 ConvertTo-Icon -File $sourceimagefile -OutputFile $targetfolder\$targetfilename.ico







