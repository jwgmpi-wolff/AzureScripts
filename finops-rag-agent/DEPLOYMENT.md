# Deployment Guide - FinOps RAG Agent to Azure AI Foundry

## Overview

This guide walks through deploying the FinOps RAG Agent to Azure AI Foundry and integrating with Copilot Studio.

## Deployment Options

| Option | Effort | Time | Best For |
|--------|--------|------|----------|
| **Copilot Studio** | 🟢 Low | 15 min | Quick MVP, Teams integration |
| **Azure CLI** | 🟡 Medium | 20 min | CI/CD pipelines, automation |
| **Portal** | 🔴 High | 30 min | Full control, manual configuration |

## Option 1: Copilot Studio (Recommended for MVP)

### Step 1: Create Copilot

1. Go to **[Copilot Studio](https://copilotstudio.microsoft.com/)**
2. Click **Create** → **Custom Copilot**
3. Enter details:
   - **Name**: FinOps RAG Agent
   - **Description**: Azure FinOps cost optimization assistant
4. Click **Create**

### Step 2: Configure System Instructions

1. In the copilot editor, go **Settings** → **System instructions**
2. Paste the system prompt:

```
You are an expert Azure FinOps assistant specializing in cloud cost optimization, governance, and best practices.

Your role:
- Provide actionable cost optimization recommendations based on Azure best practices
- Analyze current resource configurations and spending patterns
- Recommend Reserved Instances (RI) and Savings Plan opportunities
- Guide on proper governance, tagging, and policy implementation
- Cite all recommendations with sources from the knowledge base

Rules:
- Only answer using retrieved FinOps knowledge base documents
- Prioritize Azure cost optimization best practices
- Never fabricate pricing data or statistics
- Flag uncertain recommendations clearly
```

3. Click **Save**

### Step 3: Configure Actions/Tools

1. Go **Actions** → **Create new action**
2. Create action for knowledge retrieval:
   - **Name**: `retrieveFinOpsGuidance`
   - **URL**: (you'll configure this after deploying backend API)
   - **Description**: Retrieve FinOps best practices from knowledge base

3. Add parameters:
   - `query` (string): The user's question
   - `category` (string, optional): Document category filter

4. Save

### Step 4: Test in Copilot Studio

1. Use the **Test** button at the bottom right
2. Try queries like:
   - "How can we reduce AKS costs?"
   - "What are the benefits of Savings Plans?"
   - "Check our resource tagging compliance"

### Step 5: Publish to Teams (Optional)

1. Click **Publish** → **Microsoft Teams**
2. Add to your Teams workspace
3. Users can now interact with the agent in Teams

**Result**: ✅ Agent available in Copilot Studio and Teams

---

## Option 2: Deploy with Azure CLI

### Step 1: Create Azure AI Foundry Project

```bash
SUBSCRIPTION_ID="5755893a-8056-4ba8-9916-1133c80a80f3"
RESOURCE_GROUP="WolffFInopsAIrg"
PROJECT_NAME="finops-rag-project"

az ai project create \
    --name $PROJECT_NAME \
    --resource-group $RESOURCE_GROUP \
    --display-name "FinOps RAG Agent" \
    --subscription $SUBSCRIPTION_ID
```

### Step 2: Get Project Details

```bash
PROJECT_ID=$(az ai project show \
    --name $PROJECT_NAME \
    --resource-group $RESOURCE_GROUP \
    --query id -o tsv)

echo "Project ID: $PROJECT_ID"
```

### Step 3: Configure Agent

Create `deployment-config.json`:

```json
{
  "name": "finops-rag-agent",
  "version": "1.0.0",
  "runtime": "python-3.11",
  "entry_point": "src/agent.py",
  "environment_variables": {
    "AZURE_OPENAI_ENDPOINT": "${AZURE_OPENAI_ENDPOINT}",
    "SEARCH_ENDPOINT": "${SEARCH_ENDPOINT}",
    "LOG_LEVEL": "INFO"
  },
  "compute": {
    "instance_type": "standard_ds2_v2",
    "min_instances": 1,
    "max_instances": 3
  },
  "monitoring": {
    "enabled": true,
    "app_insights_enabled": true
  }
}
```

### Step 4: Deploy Agent

```bash
AGENT_NAME="finops-rag-agent"

az ai agent create \
    --name $AGENT_NAME \
    --project $PROJECT_NAME \
    --resource-group $RESOURCE_GROUP \
    --source-dir . \
    --config deployment-config.json
```

### Step 5: Get Endpoint

```bash
AGENT_ENDPOINT=$(az ai agent show \
    --name $AGENT_NAME \
    --project $PROJECT_NAME \
    --resource-group $RESOURCE_GROUP \
    --query "properties.endpoint" -o tsv)

echo "Agent Endpoint: $AGENT_ENDPOINT"
```

### Step 6: Test Agent

```bash
# Create test request
curl -X POST "$AGENT_ENDPOINT/invoke" \
  -H "Authorization: Bearer $(az account get-access-token --query accessToken -o tsv)" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "How can we optimize AKS costs?",
    "context": {"subscription_id": "'$SUBSCRIPTION_ID'"}
  }'
```

---

## Option 3: Deploy via Portal

### Step 1: Create Foundry Project

1. Go to **Azure Portal** → **Create a resource**
2. Search for **"Azure AI Foundry"**
3. Click **Create**
4. Fill in:
   - **Project name**: finops-rag-project
   - **Resource group**: WolffFInopsAIrg
   - **Location**: East US 2
5. Click **Create**

### Step 2: Configure AI Services

1. In Foundry Project → **Settings** → **AI services**
2. Connect:
   - **Azure OpenAI**: Select wolffFinopsAI
   - **AI Search**: Select wolffFinopsAIsearch

### Step 3: Upload Agent Code

1. Go **Code** → **Upload files**
2. Upload:
   - `src/agent.py`
   - `src/rag_agent.py`
   - `src/azure_apis.py`
   - `config.py`
   - `requirements.txt`

### Step 4: Configure Deployment

1. Go **Deployments** → **New deployment**
2. Fill in:
   - **Deployment name**: finops-rag-v1
   - **Entry point**: src/agent.py
   - **Environment variables**:
     ```
     AZURE_OPENAI_ENDPOINT=https://wolfffinopsai.openai.azure.com/
     SEARCH_ENDPOINT=https://wolfffinopsaisearch.search.windows.net
     LOG_LEVEL=INFO
     ```

3. Click **Deploy**

### Step 5: Configure Managed Identity

1. Go **Settings** → **Identity**
2. Enable **System-assigned managed identity**
3. Add role assignments:
   - **Cognitive Services OpenAI User** (for OpenAI)
   - **Search Service Contributor** (for Search)

### Step 6: Monitor Deployment

1. Go **Deployments** → Watch status
2. Once status is "Healthy", agent is ready

---

## Post-Deployment Configuration

### Step 1: Connect to Copilot Studio

1. In Copilot Studio, go **Settings** → **Integrations**
2. Add **Custom Endpoint**:
   - **Endpoint URL**: `$AGENT_ENDPOINT/invoke`
   - **Authentication**: Bearer token (use Managed Identity)
3. Save

### Step 2: Test Integration

```bash
# Send test message to agent
curl -X POST "$AGENT_ENDPOINT/invoke" \
  -H "Authorization: Bearer $(az account get-access-token --query accessToken -o tsv)" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test message"}'
```

### Step 3: Enable Monitoring

1. Go **Monitoring** → **Application Insights**
2. View logs and metrics:

```kusto
customEvents
| where name == "finops_query"
| summarize 
    Count=count(),
    AvgTokens=avg(toreal(customDimensions.tokens)),
    AvgLatency=avg(duration)
  by bin(timestamp, 1h)
| render timechart
```

### Step 4: Configure Alerts

```bash
# Alert when agent errors increase
az monitor metrics alert create \
    --name "FinOps Agent Errors" \
    --resource-group $RESOURCE_GROUP \
    --description "Alert when error rate exceeds 5%" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.AppPlatform/Spring/finops-agent" \
    --window-size PT5M \
    --evaluation-frequency PT1M
```

---

## Troubleshooting Deployment

### Agent Status Check

```bash
az ai agent show \
    --name finops-rag-agent \
    --project finops-rag-project \
    --resource-group WolffFInopsAIrg
```

### View Logs

```bash
# Get logs from Application Insights
az monitor app-insights query \
    --app finops-agent-insights \
    --analytics-query "
      traces
      | where severityLevel == 2  // Errors
      | order by timestamp desc
    "
```

### Restart Agent

```bash
az ai agent delete \
    --name finops-rag-agent \
    --project finops-rag-project \
    --resource-group WolffFInopsAIrg

# Re-deploy
az ai agent create \
    --name finops-rag-agent \
    --project finops-rag-project \
    --resource-group WolffFInopsAIrg \
    --source-dir .
```

### Check Connectivity

```bash
# Test OpenAI connection
python -c "
from openai import AzureOpenAI
from config import AzureConfig
config = AzureConfig()
client = AzureOpenAI(api_key=config.OPENAI_API_KEY, azure_endpoint=config.OPENAI_ENDPOINT, api_version=config.OPENAI_API_VERSION)
response = client.chat.completions.create(model='gpt-4o-mini', messages=[{'role': 'user', 'content': 'test'}])
print('✓ OpenAI connected')
"

# Test Search connection
python -c "
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential
from config import AzureConfig
config = AzureConfig()
client = SearchClient(endpoint=config.SEARCH_ENDPOINT, index_name=config.SEARCH_INDEX_NAME, credential=AzureKeyCredential(config.SEARCH_API_KEY))
stats = client.get_search_statistics()
print(f'✓ Search connected: {stats.document_count} documents indexed')
"
```

---

## CI/CD Integration

### GitHub Actions Pipeline

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy FinOps Agent

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy Agent
      run: |
        az ai agent deploy \
            --name finops-rag-agent \
            --project finops-rag-project \
            --resource-group WolffFInopsAIrg \
            --source-dir .
    
    - name: Run Tests
      run: |
        python -m pytest tests/
    
    - name: Notify
      if: success()
      run: echo "✅ Deployment successful"
```

---

## Next Steps

1. ✅ **Deploy**: Choose one option above
2. ✅ **Test**: Use curl or Copilot Studio to test
3. ✅ **Monitor**: Set up Application Insights alerts
4. ✅ **Iterate**: Gather feedback, improve prompts
5. ✅ **Scale**: Increase replicas if needed
6. ✅ **Integrate**: Connect to Teams, web apps, etc.

## Support

- 📖 [Azure AI Foundry Docs](https://learn.microsoft.com/azure/ai-studio/)
- 💬 [Copilot Studio Docs](https://learn.microsoft.com/microsoft-copilot-studio/)
- 🆘 [Troubleshooting Guide](TROUBLESHOOTING.md)
