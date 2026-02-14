
param(
    [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Prompt,

    # Prefer environment variables; fall back to parameters if provided
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = ''

    [Parameter(Mandatory=$false)]
    [string]$Endpoint = $env:AZURE_AI_ENDPOINT,  # e.g. https://<project>.services.ai.azure.com/models

    [Parameter(Mandatory=$false)]
    [string]$Model = "Phi-4-mini-reasoning",

    [Parameter(Mandatory=$false)]
    [int]$MaxTokens = 4096,

    [Parameter(Mandatory=$false)]
    [double]$Temperature = 0.6,

    [Parameter(Mandatory=$false)]
    [double]$TopP = 0.95,

    [Parameter(Mandatory=$false)]
    [double]$PresencePenalty = 0.0,

    [Parameter(Mandatory=$false)]
    [double]$FrequencyPenalty = 0.0,

    [Parameter(Mandatory=$false)]
    [string]$SystemMessage = "You are a helpful assistant.",

    [Parameter(Mandatory=$false)]
    [switch]$UseEntraIDToken,   # when true, use OAuth token instead of api-key

    [Parameter(Mandatory=$false)]
    [switch]$ShowFullResponse,

    [Parameter(Mandatory=$false)]
    [switch]$ShowUsage,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)




$env:AZURE_AI_ENDPOINT = "https://wolffaifoundry.services.ai.azure.com//models"
$env:AZURE_AI_API_KEY  = ''









function Get-AuthHeader {
    param([string]$ApiKey,[switch]$UseEntraIDToken,[string]$Endpoint)

    if ($UseEntraIDToken) {
        # Acquire AAD token for the endpoint resource. The audience varies by service;
        # when using a custom APIM gateway, replace $resource accordingly.
        $resource = "https://cognitiveservices.azure.com/"  # common audience for AI services; confirm for your endpoint
        $token = (Get-AzAccessToken -ResourceUrl $resource).Token
        return @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
    }

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw "No API key found. Set AZURE_AI_API_KEY or pass -ApiKey."
    }
    return @{ "api-key" = $ApiKey; "Content-Type" = "application/json" }
}

function Show-Help {
    Write-Host "`nAzure AI Fabric/Foundry Chat Script"
    Write-Host "USAGE: .\azure-ai-chat.ps1 'Your prompt' [-UseEntraIDToken]" -ForegroundColor Yellow
    Write-Host "ENV VARS: AZURE_AI_ENDPOINT, AZURE_AI_API_KEY"
}

function Test-Parameters {
    if ($Temperature -lt 0.0 -or $Temperature -gt 1.0) { throw "Temperature must be 0.0–1.0" }
    if ($TopP -lt 0.0 -or $TopP -gt 1.0) { throw "TopP must be 0.0–1.0" }
    if ($PresencePenalty -lt -2.0 -or $PresencePenalty -gt 2.0) { throw "PresencePenalty must be -2.0–2.0" }
    if ($FrequencyPenalty -lt -2.0 -or $FrequencyPenalty -gt 2.0) { throw "FrequencyPenalty must be -2.0–2.0" }
    if ($MaxTokens -lt 1 -or $MaxTokens -gt 8192) { throw "MaxTokens must be 1–8192" }
}

try {
    if ($Help) { Show-Help; return }
    Test-Parameters

    $UserPrompt = ($Prompt -join " ").Trim()
    if ([string]::IsNullOrWhiteSpace($UserPrompt)) { throw "Prompt cannot be empty." }
    if ([string]::IsNullOrWhiteSpace($Endpoint))  { throw "Endpoint is required; set AZURE_AI_ENDPOINT or pass -Endpoint." }

    Write-Host "Sending prompt..." -ForegroundColor Cyan
    Write-Host "Endpoint: $Endpoint" -ForegroundColor Gray
    Write-Host "Model   : $Model" -ForegroundColor Gray

    $headers = Get-AuthHeader -ApiKey $ApiKey -UseEntraIDToken:$UseEntraIDToken -Endpoint $Endpoint

    $bodyObj = @{
        messages = @(
            @{ role = "system"; content = $SystemMessage },
            @{ role = "user";   content = $UserPrompt }
        )
        model = $Model
        max_tokens = $MaxTokens
        temperature = $Temperature
        top_p = $TopP
        presence_penalty = $PresencePenalty
        frequency_penalty = $FrequencyPenalty
    }
    $body = $bodyObj | ConvertTo-Json -Depth 5

    $apiVersion = "2024-05-01-preview"
    $apiUrl = "$Endpoint/chat/completions?api-version=$apiVersion"

    $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $body

    if ($ShowFullResponse) {
        Write-Host "`nFULL RESPONSE:" -ForegroundColor Green
        $response | ConvertTo-Json -Depth 8
    } else {
        Write-Host "`nAI RESPONSE:" -ForegroundColor Green
        Write-Host $response.choices[0].message.content
    }

    if ($ShowUsage -or $ShowFullResponse) {
        Write-Host "`nTOKEN USAGE:" -ForegroundColor Yellow
        Write-Host "Prompt Tokens    : $($response.usage.prompt_tokens)"
        Write-Host "Completion Tokens: $($response.usage.completion_tokens)"
        Write-Host "Total Tokens     : $($response.usage.total_tokens)"
        Write-Host "Finish Reason    : $($response.choices[0].finish_reason)"
    }

} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDescription = $_.Exception.Response.StatusDescription
        Write-Host "HTTP Status: $statusCode - $statusDescription" -ForegroundColor Red
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            if ($errorBody) { Write-Host "Error Details: $errorBody" -ForegroundColor Red }
        } catch {}
    }
    Write-Host "`nSuggestions:"
    Write-Host "1) Validate AZURE_AI_ENDPOINT"
    Write-Host "2) Use -UseEntraIDToken or set AZURE_AI_API_KEY"
    Write-Host "3) Confirm model deployment & api-version"
    Write-Host "4) Check network (Private Link/APIM) and service status"
}
