
# wolff_ai_foundry_call.ps1
# Requires PowerShell 7+ for the ??= operator
#> Usage example:
#>   .\wolff_ai_foundry_call.ps1 "read in prices from c:\temp\azureprices.csv summarize count listings each region" -ShowFullResponse
#> Option

   

# wolff_ai_foundry_call.ps1
[CmdletBinding()]
param(
    # Prompt (capture remaining args as a single string)
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Prompt,

    # Endpoint & API key — default from env vars if present
    [Parameter(Mandatory = $false)]
    [string]$Endpoint = "https://wolffaifoundry.services.ai.azure.com/models",

    [Parameter(Mandatory = $false)]
    [string]$ApiKey   = ''

    # Model & generation controls (NO trailing commas in param block)
    [Parameter(Mandatory = $false)]
    [string]$Model = "Phi-4-mini-reasoning",

    [Parameter(Mandatory = $false)]
    [int]$MaxTokens = 4096,

    [Parameter(Mandatory = $false)]
    [double]$Temperature = 0.6,

    [Parameter(Mandatory = $false)]
    [double]$TopP = 0.95,

    [Parameter(Mandatory = $false)]
    [double]$PresencePenalty = 0.0,

    [Parameter(Mandatory = $false)]
    [double]$FrequencyPenalty = 0.0,

    [Parameter(Mandatory = $false)]
    [string]$SystemMessage = "helpful assistant",

    # Auth & output flags
    [Parameter(Mandatory = $false)]
    [switch]$UseEntraIDToken,

    [Parameter(Mandatory = $false)]
    [switch]$ShowFullResponse,

    [Parameter(Mandatory = $false)]
    [switch]$ShowUsage,

    [Parameter(Mandatory = $false)]
    [switch]$Help
)


 

function Show-Help {
    Write-Host "`nAzure AI Foundry Chat Script" -ForegroundColor Green
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\wolff_ai_foundry_call.ps1 'your prompt here' [-Endpoint <https://.../models>] [-ApiKey <key>] [-UseEntraIDToken] [-Temperature 0.8] [-ShowUsage] [-ShowFullResponse]"
    Write-Host "`nENV VARS:" -ForegroundColor Yellow
    Write-Host "  AZURE_AI_ENDPOINT, AZURE_AI_API_KEY"
    Write-Host "`nNOTES:" -ForegroundColor Yellow
    Write-Host "  • For API key auth: header is 'api-key: <key>'"
    Write-Host "  • For Entra ID auth: header is 'Authorization: Bearer <token>'"
    Write-Host "  • Endpoint should end with '/models' (no trailing slash)."
}

function Test-Parameters {
    if ($Temperature -lt 0.0 -or $Temperature -gt 1.0) {
        Write-Error "Temperature must be between 0.0 and 1.0"
        return $false
    }
    if ($TopP -lt 0.0 -or $TopP -gt 1.0) {
        Write-Error "TopP must be between 0.0 and 1.0"
        return $false
    }
    if ($PresencePenalty -lt -2.0 -or $PresencePenalty -gt 2.0) {
        Write-Error "PresencePenalty must be between -2.0 and 2.0"
        return $false
    }
    if ($FrequencyPenalty -lt -2.0 -or $FrequencyPenalty -gt 2.0) {
        Write-Error "FrequencyPenalty must be between -2.0 and 2.0"
        return $false
    }
    if ($MaxTokens -lt 1 -or $MaxTokens -gt 8192) {
        Write-Error "MaxTokens must be between 1 and 8192"
        return $false
    }
    return $true
}

function Get-AuthHeaders {
    param(
        [string]$Endpoint,
        [string]$ApiKey,
        [switch]$UseEntraIDToken
    )

    $headers = @{
        "Content-Type" = "application/json"
    }

    if ($UseEntraIDToken) {
        # Audience for Foundry model endpoints (Cognitive Services)
        $resource = "https://cognitiveservices.azure.com/"
        try {
            $token = (Get-AzAccessToken -ResourceUrl $resource).Token
            $headers["Authorization"] = "Bearer $token"
        }
        catch {
            throw "Failed to acquire Entra ID access token. Ensure Az.Accounts is installed and 'Connect-AzAccount' has been run."
        }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            throw "No API key. Set AZURE_AI_API_KEY or pass -ApiKey; or use -UseEntraIDToken."
        }
        # Azure AI Foundry expects 'api-key' (not Authorization for key auth)
        $headers["api-key"] = $ApiKey
    }

    return $headers
}

# --- Main ---
if ($Help) { Show-Help; return }

if (-not (Test-Parameters)) { return }

# Join prompt pieces to single string
$UserPrompt = ($Prompt -join " ").Trim()
if ([string]::IsNullOrWhiteSpace($UserPrompt)) {
    Write-Error "Prompt is empty. Use -Help for usage."
    return
}

if ([string]::IsNullOrWhiteSpace($Endpoint)) {
    throw "Endpoint required. Set AZURE_AI_ENDPOINT or pass -Endpoint."
}

# Normalize endpoint (no trailing slash). Must end with '/models'
$Endpoint = $Endpoint.TrimEnd('/')

$apiVersion = "2024-05-01-preview"
$apiUrl = "$Endpoint/chat/completions?api-version=$apiVersion"

Write-Host "Sending prompt to Azure AI Foundry..." -ForegroundColor Cyan
Write-Host "Endpoint: $Endpoint" -ForegroundColor Gray
Write-Host "Model:    $Model" -ForegroundColor Gray

try {
    $headers = Get-AuthHeaders -Endpoint $Endpoint -ApiKey $ApiKey -UseEntraIDToken:$UseEntraIDToken

    $bodyObj = @{
        messages = @(
            @{ role = "system"; content = $SystemMessage },
            @{ role = "user";   content =  ($UserPrompt +  ' give me clean version only and always skip reasoning')}
        )
        model              = $Model
        max_tokens         = $MaxTokens
        temperature        = $Temperature
        top_p              = $TopP
        presence_penalty   = $PresencePenalty
        frequency_penalty  = $FrequencyPenalty
    }

    $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body ($bodyObj | ConvertTo-Json -Depth 5)

    if ($ShowFullResponse) {
        Write-Host "`nFULL RESPONSE" -ForegroundColor Green
        $response | ConvertTo-Json -Depth 8
    }

    Write-Host "`nAI RESPONSE:" -ForegroundColor Green
    $content = $response.choices[0].message.content
    if ([string]::IsNullOrWhiteSpace($content)) {
        $content = ($response.choices[0] | ConvertTo-Json -Depth 5)
    }
    Write-Host $content -ForegroundColor White

    if ($ShowUsage -or $ShowFullResponse) {
        Write-Host "`nTOKEN USAGE:" -ForegroundColor Yellow
        Write-Host ("  Prompt Tokens    : {0}" -f $response.usage.prompt_tokens)
        Write-Host ("  Completion Tokens: {0}" -f $response.usage.completion_tokens)
        Write-Host ("  Total Tokens     : {0}" -f $response.usage.total_tokens)
        Write-Host ("  Model            : {0}" -f $response.model)
        Write-Host ("  Finish Reason    : {0}" -f $response.choices[0].finish_reason)
        Write-Host "`nRequest completed successfully!" -ForegroundColor Green
    }
}
catch {
    Write-Host "`nERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        if ($errorBody) {
            Write-Host "`nError Details:" -ForegroundColor Red
            Write-Host $errorBody -ForegroundColor Red
        }
    }

    Write-Host "`nSuggestions:" -ForegroundColor Yellow
    Write-Host "  1) Validate AZURE_AI_ENDPOINT (must end with '/models')"
    Write-Host "  2) Use -UseEntraIDToken or set AZURE_AI_API_KEY"
    Write-Host "  3) Confirm model is deployed & api-version = $apiVersion"
    Write-Host "  4) Check network (Private Link/APIM) and service status"
}

