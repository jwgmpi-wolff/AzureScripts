 
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module Az -Scope CurrentUser
 



$tenantId = "<your-tenant-id>"
$clientId = "<your-client-id>"
$clientSecret = "<your-client-secret>"

$body = @{
 grant_type = "client_credentials"
 scope = "https://graph.microsoft.com/.default"
 client_id = $clientId
 client_secret = $clientSecret
}


$headers = @{ Authorization = "Bearer $accessToken" }

$callRecordsUrl = "https://graph.microsoft.com/v1.0/communications/callRecords"
$response = Invoke-RestMethod -Uri $callRecordsUrl -Headers $headers -Method Get

$response.value | Select-Object id, startDateTime, endDateTime, modalities
 

 $callId = "<call-record-id>"
$participantsUrl = "https://graph.microsoft.com/v1.0/communications/callRecords/$callId/participants"

$participants = Invoke-RestMethod -Uri $participantsUrl -Headers $headers -Method Get
$participants.value | Select-Object displayName, userPrincipalName




$subscriptionKey = "<your-speech-key>"
$region = "<your-region>"
$audioUrl = "<blob-url-of-audio-file>"

$headers = @{
 "Ocp-Apim-Subscription-Key" = $subscriptionKey
 "Content-Type" = "application/json"
}

$body = @{
 contentUrls = @($audioUrl)
 locale = "en-US"
 displayName = "TeamsCallTranscription"
} | ConvertTo-Json -Depth 3

Invoke-RestMethod -Uri "https://$region.api.cognitive.microsoft.com/speechtotext/v3.0/transcriptions" `
 -Method Post -Headers $headers -Body $body






































