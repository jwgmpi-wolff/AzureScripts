 

# Define variables$DriveLetter= "Z:"
# Choose the drive letter you want to map

$SharePath= "\\wolffgovaddc01\usershare"
# Replace with the actual network share path

Get-FileShare -Name usershare

$server = $SharePath.split('\')[2]
$server

$DriveLetter = 'P'


# Create a new GPO

$GPOName= "Users_Mapped_Drives"
#New-GPO -Name $GPOName

 #$OUPath = "OU=Users,OU=$gponame,DC=wolffgov,DC=com"
 $OUPath = "ou=users,DC=wolffgov,dc=com"
 $ous = Get-ADOrganizationalUnit -Filter *

 $outselected = $ous | where DistinguishedName -like '*testshare*' | select DistinguishedName

New-GPO -Name $GPOName  | New-GPLink -Target "$($outselected.DistinguishedName)" -LinkEnabled Yes -Domain 'wolffgov.com' -Enforced Yes

 

# Link the GPO to the appropriate organizational unit (OU)

 

# Get Group Policy inheritance information for a specific OU
Get-GPInheritance -Target $($outselected.DistinguishedName) | Select-Object -Property ContainerName, GpoLinks, InheritedGpoLinks
 
 <# Cleanup GPpreferencereg items ##########

 $vars = "Action","Location","Label","Letter"
 foreach($var in $vars)
 {


 $cleangpoparams = @{
    Name      = "$GPOName"
    Context   = 'User'
    Key       = 'HKEY_CURRENT_USER\Network\$DriveLetter'
    ValueName = "$var"
}

Remove-GPPrefRegistryValue @cleangpoparams
}

#>



# Configure drive mapping settings
$DriveMapping= New-Object -TypeName PSObject

$DriveMapping | Add-Member -MemberType NoteProperty -Name "Action" -Value "Update" 
$DriveMapping| Add-Member -MemberType NoteProperty -Name "Location" -Value $SharePath 
$DriveMapping | Add-Member -MemberType NoteProperty -Name "Label" -Value  "Shared Drive" 
$DriveMapping | Add-Member -MemberType NoteProperty -Name "Letter" -Value $DriveLetter
$DriveMapping


# Add the drive mapping to the 

$params = @{
    Name      = "$GPOName"
    Context   = 'User'
    Key       = "HKEY_CURRENT_USER\Network\$DriveLetter"
    ValueName = 'Letter'
    Value     = "$DriveLetter"
    Type      = 'String'
    Action    = 'Update'
}
Set-GPPrefRegistryValue @params

$params = @{
    Name      = "$GPOName"
    Context   = 'User'
    Key       = "HKEY_CURRENT_USER\Network\$DriveLetter"
    ValueName = 'Location'
    Value     = "$($DriveMapping.Location)"
    Type      = 'String'
    Action    = 'Update'
}
Set-GPPrefRegistryValue @params

$params = @{
    Name      = "$GPOName"
    Context   = 'User'
    Key       = "HKEY_CURRENT_USER\Network\$DriveLetter"
    ValueName = 'Label'
    Value     = "$($DriveMapping.Label)"
    Type      = 'String'
    Action    = 'Update'
}
Set-GPPrefRegistryValue @params
 


$gpoparams = @{
    Context = 'User'
    Key     = "HKEY_CURRENT_USER\Network\$DriveLetter"
    Name    = "$GPOName"
}

Get-GPPrefRegistryValue @gpoparams


   New-ADGroup -Name "test_sharesusers"  -GroupCategory Security -GroupScope Global -DisplayName "testshareusers" -Path "$($outselected.DistinguishedName)" -Description "Members of this group are file share users and  Administrators"
        #  New-ADGroup "test_shares" -path 'OU=Users,OU=shareusers,dc=wolffgov,DC=com' -GroupScope Global -PassThru –Verbose
        Add-AdGroupMember -Identity test_sharesusers -Members jerrywolff,wolffgovadmin

    

# Apply the GPO changes
gpupdate /force
repadmin /syncall /e /P






