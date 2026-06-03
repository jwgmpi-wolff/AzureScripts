# FinOps RAG Agent Setup Script
# PowerShell script to set up the FinOps RAG system on Azure

param(
    [string]$SubscriptionId = "5755893a-8056-4ba8-9916-1133c80a80f3",
    [string]$ResourceGroup = "WolffFInopsAIrg",
    [string]$Location = "eastus2",
    [string]$OpenAIResourceName = "wolffFinopsAI",
    [string]$SearchResourceName = "wolffFinopsAIsearch",
    [string]$SkipResourceCreation = $false
)

Write-Host "================================" -ForegroundColor Green
Write-Host "FinOps RAG Agent Setup"
Write-Host "================================" -ForegroundColor Green

# Check prerequisites
Write-Host "`n1️⃣  Checking prerequisites..." -ForegroundColor Cyan

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure CLI not installed. Please install from https://aka.ms/azcli" -ForegroundColor Red
    exit 1
}

# Check Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python not installed. Please install Python 3.10+" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Prerequisites OK" -ForegroundColor Green

# Set subscription
Write-Host "`n2️⃣  Setting Azure subscription..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId
Write-Host "✓ Subscription set" -ForegroundColor Green

# Check resource group
Write-Host "`n3️⃣  Checking resource group..." -ForegroundColor Cyan
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "true") {
    Write-Host "✓ Resource group exists" -ForegroundColor Green
} else {
    Write-Host "Creating resource group..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location
    Write-Host "✓ Resource group created" -ForegroundColor Green
}

# Check Azure OpenAI
Write-Host "`n4️⃣  Checking Azure OpenAI resource..." -ForegroundColor Cyan
$openaiExists = az cognitiveservices account show `
    --name $OpenAIResourceName `
    --resource-group $ResourceGroup `
    --query id -o tsv 2>$null

if ($openaiExists) {
    Write-Host "✓ Azure OpenAI resource found" -ForegroundColor Green
    $openaiEndpoint = az cognitiveservices account show `
        --name $OpenAIResourceName `
        --resource-group $ResourceGroup `
        --query properties.endpoint -o tsv
    Write-Host "  Endpoint: $openaiEndpoint"
} else {
    Write-Host "⚠️  Azure OpenAI resource not found" -ForegroundColor Yellow
    Write-Host "Please create it manually in the Azure Portal" -ForegroundColor Yellow
}

# Check AI Search
Write-Host "`n5️⃣  Checking Azure AI Search resource..." -ForegroundColor Cyan
$searchExists = az search service show `
    --name $SearchResourceName `
    --resource-group $ResourceGroup `
    --query id -o tsv 2>$null

if ($searchExists) {
    Write-Host "✓ Azure AI Search resource found" -ForegroundColor Green
    $searchEndpoint = az search service show `
        --name $SearchResourceName `
        --resource-group $ResourceGroup `
        --query endpoint -o tsv
    Write-Host "  Endpoint: $searchEndpoint"
} else {
    Write-Host "⚠️  Azure AI Search resource not found" -ForegroundColor Yellow
    Write-Host "Please create it manually in the Azure Portal" -ForegroundColor Yellow
}

# Set up Python environment
Write-Host "`n6️⃣  Setting up Python environment..." -ForegroundColor Cyan

if (-not (Test-Path "venv")) {
    python -m venv venv
    Write-Host "✓ Virtual environment created" -ForegroundColor Green
} else {
    Write-Host "✓ Virtual environment already exists" -ForegroundColor Green
}

# Activate venv
& ".\venv\Scripts\Activate.ps1"

# Install dependencies
Write-Host "`n7️⃣  Installing Python dependencies..." -ForegroundColor Cyan
pip install --upgrade pip
pip install -r requirements.txt
Write-Host "✓ Dependencies installed" -ForegroundColor Green

# Set environment variables
Write-Host "`n8️⃣  Setting environment variables..." -ForegroundColor Cyan

# Get API keys
Write-Host "Getting API keys from Key Vault..." -ForegroundColor Yellow

$openaiKey = az cognitiveservices account keys list `
    --name $OpenAIResourceName `
    --resource-group $ResourceGroup `
    --query key1 -o tsv 2>$null

$searchKey = az search admin-key show `
    --service-name $SearchResourceName `
    --resource-group $ResourceGroup `
    --query primaryKey -o tsv 2>$null

if ($openaiKey -and $searchKey) {
    $env:AZURE_OPENAI_KEY = $openaiKey
    $env:AZURE_OPENAI_ENDPOINT = $openaiEndpoint
    $env:SEARCH_API_KEY = $searchKey
    $env:SEARCH_ENDPOINT = $searchEndpoint
    
    Write-Host "✓ Environment variables set" -ForegroundColor Green
} else {
    Write-Host "⚠️  Could not retrieve API keys. Please set manually:" -ForegroundColor Yellow
    Write-Host "   \$env:AZURE_OPENAI_KEY = '<your-openai-key>'" -ForegroundColor Yellow
    Write-Host "   \$env:SEARCH_API_KEY = '<your-search-key>'" -ForegroundColor Yellow
}

# Create Search Index
Write-Host "`n9️⃣  Creating Azure AI Search index..." -ForegroundColor Cyan
python -c "
from src.config import AzureConfig
from src.search_indexer import SearchIndexManager

config = AzureConfig()
manager = SearchIndexManager(config.SEARCH_ENDPOINT, config.SEARCH_API_KEY)
manager.create_index(config.SEARCH_INDEX_NAME, config.SEARCH_INDEX_SCHEMA)
"
Write-Host "✓ Search index created/verified" -ForegroundColor Green

# Next steps
Write-Host "`n✅ Setup Complete!" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Add your FinOps documents to the knowledgebase folder"
Write-Host "2. Run: python -m src.document_processor" -ForegroundColor Yellow
Write-Host "3. Run: python -m src.search_indexer" -ForegroundColor Yellow
Write-Host "4. Test the agent: python src/agent.py" -ForegroundColor Yellow
Write-Host "5. Deploy to Azure AI Foundry"
Write-Host ""
