# Public IP cache file
$global:IPCacheFile = "$env:APPDATA\PublicIPCache.txt"
$global:PublicIP = ""
$global:LastCheckTime = $null
$global:LastStatus = $null
$global:LastPrintedStatus = $null

# Enforce admin-only module installs and updates
function Install-Module {
    param([Parameter(ValueFromRemainingArguments=$true)] $Args)
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ($Args -notmatch '-Scope\s+AllUsers') {
            throw "Install-Module without -Scope AllUsers is disabled. Run PowerShell as Administrator and specify -Scope AllUsers."
        }
    }
    Install-Module @Args
}

function Update-Module {
    param([Parameter(ValueFromRemainingArguments=$true)] $Args)
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ($Args -notmatch '-Scope\s+AllUsers') {
            throw "Update-Module without -Scope AllUsers is disabled. Run PowerShell as Administrator and specify -Scope AllUsers."
        }
    }
    Update-Module @Args
}

# Check and persist public IP
function Check-PublicIP {
    try {
        $currentIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
        $global:PublicIP = $currentIP

        if (Test-Path $global:IPCacheFile) {
            $cachedIP = Get-Content $global:IPCacheFile
            if ($cachedIP -ne $currentIP) {
                Write-Host "⚠️ Public IP has changed: $cachedIP → $currentIP" -ForegroundColor Yellow
            }
        }

        $currentIP | Set-Content $global:IPCacheFile
    } catch {
        $global:PublicIP = "Unavailable"
    }
}

# Run IP check once at launch
Check-PublicIP

# Custom two-line prompt
function prompt {
    $now = Get-Date
    $cacheDuration = 300 # seconds

    if (-not $global:LastCheckTime -or ($now - $global:LastCheckTime).TotalSeconds -gt $cacheDuration) {
        # GSA Tunnel service status
        $gsaServiceName = "GlobalSecureAccessTunnelingService"
        $svc = Get-Service -Name $gsaServiceName -ErrorAction SilentlyContinue
        if ($null -eq $svc) {
            $gsaStatus = "GSA: Not Found"
        } elseif ($svc.Status -eq "Running") {
            $gsaStatus = "GSA: On"
        } else {
            $gsaStatus = "GSA: Off"
        }

        # VPN status
        $vpnProfiles = @("MSFT-AzVPN-Manual", "MSFTVPN-Manual")
        $vpnConnected = $false

        foreach ($profile in $vpnProfiles) {
            $vpn = Get-NetIPInterface | Where-Object {
                $_.InterfaceAlias -eq $profile -and $_.ConnectionState -eq "Connected"
            }
            if ($vpn) {
                $vpnConnected = $true
                break
            }
        }

        if (-not $vpnConnected) {
            $vpn = Get-NetIPInterface | Where-Object {
                $_.InterfaceDescription -match "VPN" -and $_.ConnectionState -eq "Connected"
            }
            if ($vpn) {
                $vpnConnected = $true
            }
        }

        $vpnStatus = if ($vpnConnected) { "VPN: On" } else { "VPN: Off" }

        # Combine status
        $global:LastStatus = "[ $vpnStatus | $gsaStatus | IP: $global:PublicIP ]"
        $global:LastCheckTime = $now

        # Print status if changed
        if ($global:LastStatus -ne $global:LastPrintedStatus) {
            Write-Host $global:LastStatus -ForegroundColor Cyan
            $global:LastPrintedStatus = $global:LastStatus
        }
    }

    $location = Get-Location
    "PS $location> "
}
