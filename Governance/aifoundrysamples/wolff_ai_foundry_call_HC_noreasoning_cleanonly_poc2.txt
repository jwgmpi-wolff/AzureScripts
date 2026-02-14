
# wolff_ai_foundry_call.ps1
# PowerShell 7+  (uses modern operators/features)

[CmdletBinding()]
param(
    # Capture remaining args as a single prompt string
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Prompt,

    # --- Azure AI Foundry project endpoint (must end with /models) ---
    [Parameter(Mandatory = $false)]
    [string]$Endpoint =  "https://geral-mj7f4szj-eastus2.cognitiveservices.azure.com/models",

    # API key (secret) or use -UseEntraIDToken
    [Parameter(Mandatory = $false)]
    [string]$ApiKey   = ''

    # Model deployed/available in the Foundry project
    [Parameter(Mandatory = $false)]
    [string]$Model = "Phi-4-mini-reasoning",

    # Generation controls
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
    [string]$SystemMessage = "You are a helpful assistant.",

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
    Write-Host "  .\wolff_ai_foundry_call.ps1 'your prompt here' [-Endpoint https://<project>.services.ai.azure.com/models] [-ApiKey <key>] [-UseEntraIDToken] [-Model gpt-4o-mini] [-Temperature 0.8] [-ShowUsage] [-ShowFullResponse]"
    Write-Host "`nENV VARS:" -ForegroundColor Yellow
    Write-Host "  AZURE_AI_ENDPOINT (must end with /models), AZURE_AI_API_KEY"
    Write-Host "`nNOTES:" -ForegroundColor Yellow
    Write-Host "  • API key auth header: 'api-key: <key>'"
    Write-Host "  • Entra ID auth header: 'Authorization: Bearer <token>'"
    Write-Host "  • Endpoint should end with '/models' (no trailing slash is fine)."
}

function Test-Parameters {
    if ($Temperature -lt 0.0 -or $Temperature -gt 1.0) { Write-Error "Temperature must be 0.0..1.0"; return $false }
    if ($TopP -lt 0.0 -or $TopP -gt 1.0) { Write-Error "TopP must be 0.0..1.0"; return $false }
    if ($PresencePenalty -lt -2.0 -or $PresencePenalty -gt 2.0) { Write-Error "PresencePenalty must be -2.0..2.0"; return $false }
    if ($FrequencyPenalty -lt -2.0 -or $FrequencyPenalty -gt 2.0) { Write-Error "FrequencyPenalty must be -2.0..2.0"; return $false }
    if ($MaxTokens -lt 1 -or $MaxTokens -gt 8192) { Write-Error "MaxTokens must be 1..8192"; return $false }
    return $true
}

function Get-AuthHeaders {
    param(
        [switch]$UseEntraIDToken,
        [string]$ApiKey
    )

    $headers = @{ "Content-Type" = "application/json" }

    if ($UseEntraIDToken) {
        # Audience for Cognitive Services/Foundry endpoints
        $resource = "https://cognitiveservices.azure.com/"
        try {
            $token = (Get-AzAccessToken -ResourceUrl $resource).Token
            $headers["Authorization"] = "Bearer $token"
        } catch {
            throw "Failed to acquire Entra ID token. Install Az.Accounts and run Connect-AzAccount."
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            throw "No API key. Set AZURE_AI_API_KEY or pass -ApiKey; or use -UseEntraIDToken."
        }
        $headers["api-key"] = $ApiKey
    }
    return $headers
}

# --- Main ---
if ($Help) { Show-Help; return }
if (-not (Test-Parameters)) { return }

# Join prompt
$UserPrompt = ($Prompt -join " ").Trim()
if ([string]::IsNullOrWhiteSpace($UserPrompt)) { Write-Error "Prompt is empty."; return }

if ([string]::IsNullOrWhiteSpace($Endpoint)) {
    throw "Endpoint required. Set AZURE_AI_ENDPOINT or pass -Endpoint."
}

# Normalize endpoint (no trailing slash), must end with /models
$Endpoint = $Endpoint.TrimEnd('/')

if (-not $Endpoint.EndsWith("/models")) {
    throw "Invalid endpoint. For Azure AI Foundry, the project endpoint must end with '/models'."
}

# API version and URL for Foundry chat/completions
$apiVersion = "2024-05-01-preview"
$apiUrl     = "$Endpoint/chat/completions?api-version=$apiVersion"

Write-Host "Sending prompt to Azure AI Foundry..." -ForegroundColor Cyan
Write-Host "Endpoint: $Endpoint" -ForegroundColor Gray
Write-Host "Model:    $Model" -ForegroundColor Gray

try {
    $headers = Get-AuthHeaders -UseEntraIDToken:$UseEntraIDToken -ApiKey $ApiKey

    $bodyObj = @{
        messages = @(
            @{ role = "system"; content = $SystemMessage },
            @{ role = "user";   content = $UserPrompt }
        )
        model             = $Model
        max_tokens        = $MaxTokens
        temperature       = $Temperature
        top_p             = $TopP
        presence_penalty  = $PresencePenalty
        frequency_penalty = $FrequencyPenalty
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
    Write-Host "  3) Confirm model exists in the Foundry project & api-version = $apiVersion"
    Write-Host "  4) Check network (Private Link/APIM) and service status"
}
