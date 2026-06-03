#!/bin/bash

# FinOps RAG Agent Setup Script (Bash)
# For Linux/macOS environments

SUBSCRIPTION_ID="5755893a-8056-4ba8-9916-1133c80a80f3"
RESOURCE_GROUP="WolffFInopsAIrg"
LOCATION="eastus2"
OPENAI_RESOURCE_NAME="wolffFinopsAI"
SEARCH_RESOURCE_NAME="wolffFinopsAIsearch"

echo "================================"
echo "FinOps RAG Agent Setup"
echo "================================"

# Check prerequisites
echo -e "\n1️⃣  Checking prerequisites..."

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not installed. Please install from https://aka.ms/azcli"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not installed. Please install Python 3.10+"
    exit 1
fi

echo "✓ Prerequisites OK"

# Set subscription
echo -e "\n2️⃣  Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
echo "✓ Subscription set"

# Check resource group
echo -e "\n3️⃣  Checking resource group..."
if az group exists --name "$RESOURCE_GROUP" | grep -q true; then
    echo "✓ Resource group exists"
else
    echo "Creating resource group..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    echo "✓ Resource group created"
fi

# Check Azure OpenAI
echo -e "\n4️⃣  Checking Azure OpenAI resource..."
if az cognitiveservices account show \
    --name "$OPENAI_RESOURCE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    &>/dev/null; then
    echo "✓ Azure OpenAI resource found"
    OPENAI_ENDPOINT=$(az cognitiveservices account show \
        --name "$OPENAI_RESOURCE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query properties.endpoint -o tsv)
    echo "  Endpoint: $OPENAI_ENDPOINT"
else
    echo "⚠️  Azure OpenAI resource not found"
    echo "Please create it manually in the Azure Portal"
fi

# Check AI Search
echo -e "\n5️⃣  Checking Azure AI Search resource..."
if az search service show \
    --name "$SEARCH_RESOURCE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    &>/dev/null; then
    echo "✓ Azure AI Search resource found"
    SEARCH_ENDPOINT=$(az search service show \
        --name "$SEARCH_RESOURCE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query endpoint -o tsv)
    echo "  Endpoint: $SEARCH_ENDPOINT"
else
    echo "⚠️  Azure AI Search resource not found"
    echo "Please create it manually in the Azure Portal"
fi

# Set up Python environment
echo -e "\n6️⃣  Setting up Python environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi

# Activate venv
source venv/bin/activate

# Install dependencies
echo -e "\n7️⃣  Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
echo "✓ Dependencies installed"

# Set environment variables
echo -e "\n8️⃣  Setting environment variables..."

OPENAI_KEY=$(az cognitiveservices account keys list \
    --name "$OPENAI_RESOURCE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query key1 -o tsv 2>/dev/null)

SEARCH_KEY=$(az search admin-key show \
    --service-name "$SEARCH_RESOURCE_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query primaryKey -o tsv 2>/dev/null)

if [ ! -z "$OPENAI_KEY" ] && [ ! -z "$SEARCH_KEY" ]; then
    export AZURE_OPENAI_KEY="$OPENAI_KEY"
    export AZURE_OPENAI_ENDPOINT="$OPENAI_ENDPOINT"
    export SEARCH_API_KEY="$SEARCH_KEY"
    export SEARCH_ENDPOINT="$SEARCH_ENDPOINT"
    
    echo "✓ Environment variables set"
else
    echo "⚠️  Could not retrieve API keys. Please set manually:"
    echo "   export AZURE_OPENAI_KEY='<your-openai-key>'"
    echo "   export SEARCH_API_KEY='<your-search-key>'"
fi

# Create Search Index
echo -e "\n9️⃣  Creating Azure AI Search index..."
python3 -c "
from src.config import AzureConfig
from src.search_indexer import SearchIndexManager

config = AzureConfig()
manager = SearchIndexManager(config.SEARCH_ENDPOINT, config.SEARCH_API_KEY)
manager.create_index(config.SEARCH_INDEX_NAME, config.SEARCH_INDEX_SCHEMA)
"
echo "✓ Search index created/verified"

# Summary
echo -e "\n✅ Setup Complete!"
echo -e "\nNext Steps:"
echo "1. Add your FinOps documents to the knowledgebase folder"
echo "2. Run: python -m src.document_processor"
echo "3. Run: python -m src.search_indexer"
echo "4. Test the agent: python src/agent.py"
echo "5. Deploy to Azure AI Foundry"
