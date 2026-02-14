
# Add to your param() block:
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
    [string] $Prompt,

    [Parameter(Mandatory=$false)]
    [string] $Endpoint = $env:AZURE_AI_ENDPOINT,   # e.g., "https://<your-foundry>.services.ai.azure.com/models"

    [Parameter(Mandatory=$false)]
    [string] $ApiKey = ''

    [Parameter(Mandatory=$false)]
    [string] $Model = "Phi-4-mini-reasoning",

    [Parameter(Mandatory=$false)]
    [int]    $MaxTokens = 4096,

    [Parameter(Mandatory=$false)]
    [double] $Temperature = 0.6,

    [Parameter(Mandatory=$false)]
    [double] $TopP = 0.95,

    [Parameter(Mandatory=$false)]
    [double] $PresencePenalty = 0.0,

    [Parameter(Mandatory=$false)]
    [double] $FrequencyPenalty = 0.0,

    [Parameter(Mandatory=$false)]
    [string] $SystemMessage = "helpful assistant",

    [Parameter(Mandatory=$false)]
    [switch] $UseEntraIDToken,

    [Parameter(Mandatory=$false)]
    [switch] $ShowFullResponse,

    [Parameter(Mandatory=$false)]
    [switch] $ShowUsage,

    # NEW: enforce plain, code-only output with fixed header/preamble
    [Parameter(Mandatory=$false)]
    [switch] $FormatAsHeader
)

# ---- Fixed header/preamble (what you want at the top of model output) ----
$formatHeaderText = @'
# wolff_ai_foundry_call.ps1
# Requires: PowerShell 7+ and the ?? operator
# Usage example:
#   wolff_ai_foundry_call.ps1 "read prices from C:\temp\azureprices.csv and summarize count listings per region"
# Options: ShowFullResponse
'@

# ---- Formatting instruction (model-facing, appended to the user content) ----
function Get-FormattingInstruction {
    param([string]$HeaderText)

    # This is the instruction injected to the model to enforce plain output, no boxes, no prose.
    @"
Return only a single fenced PowerShell code block. Do not include LaTeX boxes (\boxed{}), ASCII boxes, markdown callouts, or any decorative tags.
The code block must start with the exact header below, followed by two blank lines, then ONLY the task output.
Do not include any explanations, reasoning, or narrative—output only the final content.

Header (prepend exactly):
$HeaderText
"@
}

# Build final user content
$formatInstruction = if ($FormatAsHeader) { Get-FormattingInstruction -HeaderText $formatHeaderText } else { "" }

# Combine user prompt and formatting rules cleanly
$finalUserContent = ($Prompt + "`n`n" + $formatInstruction).Trim()
