
# Get only 4624 (LogonType 3) network logons, as you had
$logons = Get-WinEvent -LogName Security | Where-Object {
    $_.Id -eq 4624 -and $_.Properties[8].Value -eq 3
} | Select-Object TimeCreated, machinename, @{Name="Source";Expression={$_.Properties[18].Value}}

# Use a growable PS array and append with +=
$dcconnections = @()

foreach ($connection in $logons) {
    # Your object pattern
    $logobj = New-Object PSObject

    # --- Your nslookup approach, hardened ---
    # Skip empty or "-" source values
    $src = $connection.Source
    $vmName = $null

    if ($src -and $src -ne '-') {
        try {
            # nslookup returns text; we parse "Name: <hostname>"
            $connectedvm = nslookup $src 2>$null

            # Your pattern, but null-safe
            $nameLine = $connectedvm | Select-String -Pattern "^Name\s*:\s*(.+)"

            if ($nameLine) {
                # When Select-String matches, .Line has the entire line
                # Example: "Name: myhost.contoso.com"
                $lineText = $nameLine.Line
                # Split on the first ":" and trim
                $parts = $lineText -split ":\s*", 2
                if ($parts.Count -ge 2) {
                    $vmName = $parts[1].Trim()
                }
            }
        } catch {
            # Resolution failures are OK; leave $vmName as $null
            $vmName = $null
        }
    }

    # Add properties using your add-member style
    $logobj | Add-Member -MemberType NoteProperty -Name Timecreated -Value $connection.TimeCreated
    $logobj | Add-Member -MemberType NoteProperty -Name DCNAME      -Value $connection.MachineName
    $logobj | Add-Member -MemberType NoteProperty -Name IPAddress   -Value $src
    $logobj | Add-Member -MemberType NoteProperty -Name Vmname      -Value $vmName

    # Append with += (PowerShell array grow)
    $dcconnections += $logobj
}

# Final output in your style
$dcconnections
