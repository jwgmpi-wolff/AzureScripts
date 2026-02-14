
function Send-SmsTo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ToNumber,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$Subscriptionid,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string]$AcsResourceName
    )

    Import-Module Az.Communication

    if (-not $Subscriptionid) { throw "Subscription ID is required." }
    if (-not $ResourceGroupName) { throw "Resource group name is required." }
    if (-not $AcsResourceName) { throw "ACS resource name is required." }

    Set-AzContext -Subscription $Subscriptionid

    $acsresource = Get-AzCommunicationService -ResourceGroupName $ResourceGroupName -CommunicationServiceName $AcsResourceName -SubscriptionId $Subscriptionid
    $acsEndpoint = "https://$($acsresource.HostName)"
    $apiVersion = "2021-03-07"
    $uri = "$acsEndpoint/phoneNumbers?api-version=$apiVersion"

    $secureToken = (Get-AzAccessToken -ResourceUrl "https://communication.azure.com" -AsSecureString).Token
    $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    )

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    $phoneNumbers = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

    $validFromNumbers = ($phoneNumbers.phoneNumbers) | Where-Object {
        $_.capabilities.sms -eq "inbound+outbound"
    } | Select-Object -ExpandProperty phoneNumber

    if (-not $validFromNumbers) {
        Write-Warning "No valid 'from' numbers found that support both inbound and outbound SMS."
        return
    }

    $keys = Get-AzCommunicationServiceKey -ResourceGroupName $ResourceGroupName -CommunicationServiceName $AcsResourceName
    $connectionString = "endpoint=https://$($AcsResourceName).communication.azure.com/;accesskey=$($keys.PrimaryKey)"

    $ToNumber = $ToNumber.Trim()
    $Message = $Message.Trim()

    $logPath = "C:\temp\smslog.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $smsSent = $false

    foreach ($fromNumber in $validFromNumbers) {
        $fromNumber = $fromNumber.Trim()
        Write-Host "Trying to send SMS from: $fromNumber"
 
    $errorActionPreference = 'SilentlyContinue'
    $result = az communication sms send `
        --connection-string "$connectionString" `
        --sender "$validFromNumber" `
        --recipient "$ToNumber" `
        --message "$Message" 
    Add-Content -Path $logPath -Value "$timestamp - $result"

    Write-Host "`n--- SMS Sent ---`n$result"

 


                Write-Host "`n--- SMS Sent Successfully from $fromNumber ---"
                $smsSent = $true

     
 
    }
 
}

Export-ModuleMember -Function Send-SmsTo
