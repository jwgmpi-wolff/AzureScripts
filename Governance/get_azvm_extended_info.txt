$computerSystemProduct = Get-WmiObject -class Win32_ComputerSystemProduct  

$computerSystemProduct


 $computer = $env:computername
 $sOS =Get-WmiObject -class Win32_OperatingSystem -computername $computer
 $sOS


$info = Get-CimInstance -class Win32_OperatingSystem -computername $computer
$info | Fl *
