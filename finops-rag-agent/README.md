# FinOps RAG Agent 🚀

A production-ready **Retrieval-Augmented Generation (RAG) Agent** for Azure FinOps powered by Azure OpenAI, Azure AI Search, and Azure AI Foundry.

## Architecture Overview

```
Users (Web / Teams / Copilot Studio)
    ↓
Azure AI Foundry Agent
    ↓
Azure OpenAI (GPT-4o-mini) + Prompt Flow
    ↓
Azure AI Search (Vector + Semantic + Hybrid Search)
    ↓
FinOps Knowledge Base (RAG)
    ↓
Live Azure Data Sources
  - Cost Management API
  - Azure Advisor
  - Azure Resource Graph
  - Billing Exports
```

## Features

✅ **RAG-Powered Responses**
- Vector search with semantic ranking
- Hybrid search (lexical + semantic + vector)
- Automatic citation of sources
- Hallucination prevention

✅ **Live Azure Integration**
- Real-time cost data from Cost Management API
- Advisor recommendations (cost, reliability)
- Resource inventory via Resource Graph
- Budget alerts and forecasting

✅ **FinOps Capabilities**
- AKS cost optimization
- VM sizing and right-sizing
- Reserved Instances and Savings Plans analysis
- Orphaned resource detection
- Tagging compliance checks
- Governance guidance

✅ **Enterprise Ready**
- Managed Identity authentication
- Responsible AI controls
- Content filtering and PII detection
- Application Insights monitoring
- RBAC-aware retrieval

## Prerequisites

### Azure Services
- **Azure OpenAI** (gpt-4o-mini, text-embedding-3-large)
- **Azure AI Search** (S1 or higher recommended)
- **Azure Storage Account** (for documents)
- **Azure Key Vault** (for secrets)
- **Application Insights** (for monitoring)

### Local Requirements
- Python 3.10+
- Azure CLI 2.50+
- PowerShell 7+ (for setup on Windows)
- Git

## Quick Start

### 1. Clone and Setup

```bash
cd finops-rag-agent
```

**On Windows (PowerShell):**
```powershell
.\setup.ps1 -SubscriptionId "your-subscription-id" `
           -ResourceGroup "WolffFInopsAIrg" `
           -Location "eastus2"
```

**On Linux/macOS (Bash):**
```bash
chmod +x setup.sh
./setup.sh
```

### 2. Prepare Your Knowledge Base

Copy your FinOps documents into the appropriate folders:

```
knowledgebase/
├── aks/                      # AKS cost optimization docs
├── vm/                       # VM sizing and optimization
├── sql/                      # SQL database guidance
├── postgres/                 # PostgreSQL optimization
├── governance/               # Governance and policy
├── tagging/                  # Tagging best practices
├── cost-optimization/        # General cost optimization
└── reserved-instances/       # RI/Savings Plan guidance
```

Supported formats: `.pptx`, `.pdf`, `.md`, `.txt`

### 3. Process Documents

```bash
# Process all documents and generate chunks
python -m src.document_processor
```

This will:
- Extract text from PPTX, PDF, Markdown, and text files
- Split into optimal chunks (1000 tokens, 200 overlap)
- Save to `chunks.jsonl`

### 4. Generate Embeddings and Index

```bash
# Generate embeddings and index into Azure AI Search
python -m src.search_indexer
```

This will:
- Generate vector embeddings (text-embedding-3-large)
- Create semantic index in Azure AI Search
- Enable hybrid search (vector + semantic + lexical)

### 5. Test Locally

```bash
# Test the agent with sample queries
python src/agent.py
```

Expected output:
```
========================
Query: How can we optimize AKS costs?
========================

Answer: [RAG-powered response with sources]

Sources: AKS_Cost_Guide.pptx, Kubernetes_Best_Practices.pdf
Tokens used: 1234
```

## File Structure

```
finops-rag-agent/
├── config.py                          # Configuration and constants
├── requirements.txt                   # Python dependencies
├── agent.yaml                         # Agent configuration
├── setup.ps1                          # Windows setup script
├── setup.sh                           # Linux/macOS setup script
│
├── .foundry/
│   └── agent-metadata.yaml            # Azure AI Foundry metadata
│
├── knowledgebase/                     # FinOps knowledge base
│   ├── aks/
│   ├── vm/
│   ├── sql/
│   ├── governance/
│   └── cost-optimization/
│
└── src/
    ├── agent.py                       # Main agent entry point
    ├── document_processor.py           # Document processing pipeline
    ├── search_indexer.py              # Embedding and indexing
    ├── rag_agent.py                   # RAG retrieval and response
    └── azure_apis.py                  # Cost Mgmt, Advisor, Resource Graph
```

## Configuration

Edit `config.py` to customize:

```python
# Azure OpenAI
OPENAI_RESOURCE_NAME = "wolffFinopsAI"
CHAT_DEPLOYMENT = "gpt-4o-mini"
EMBEDDING_DEPLOYMENT = "text-embedding-3-large"

# Azure AI Search
SEARCH_SERVICE_NAME = "wolffFinopsAIsearch"
SEARCH_INDEX_NAME = "finops-index"

# Knowledge Base Processing
CHUNK_SIZE = 1000          # Optimal: 800-1500 tokens
CHUNK_OVERLAP = 200
TOP_K = 5                  # Number of documents to retrieve
```

## Deployment to Azure AI Foundry

### Option 1: Using Azure CLI

```bash
# Create Foundry project
az ai project create \
    --name finops-rag-project \
    --resource-group WolffFInopsAIrg

# Deploy agent
az ai agent create \
    --name finops-rag-agent \
    --project finops-rag-project \
    --source-dir . \
    --entry-point src/agent.py
```

### Option 2: Using Copilot Studio (Fastest)

1. Go to **Copilot Studio** → **Create a new copilot**
2. Select **Environments** → **Agent (Custom)**
3. Configure:
   - **Name**: FinOps RAG Agent
   - **Description**: Cost optimization and governance assistant
   - **System Prompt**: (paste from config.py)
4. Add skills/tools from `agent.yaml`
5. Publish to Teams

### Option 3: Using Azure AI Foundry Portal

1. **Create Project**: finops-rag-project
2. **Upload Agent Code**: src/agent.py
3. **Configure**:
   - Deployment: Standard (1 instance minimum)
   - Authentication: Managed Identity
   - Monitoring: Application Insights enabled
4. **Deploy**
5. **Test**: Use the provided chat interface

## Integration Examples

### With Teams Bot

```python
from botbuilder.core import TurnContext
from src.agent import FinOpsAgentHandler

class FinOpsTeamsBot:
    def __init__(self):
        self.handler = FinOpsAgentHandler()
    
    async def on_message_activity(self, turn_context: TurnContext):
        user_message = turn_context.activity.text
        response = self.handler.handle_message(user_message)
        await turn_context.send_activity(response["response"])
```

### With FastAPI

```python
from fastapi import FastAPI
from src.agent import FinOpsAgentHandler

app = FastAPI()
handler = FinOpsAgentHandler()

@app.post("/api/ask")
async def ask(query: str):
    return handler.handle_message(query)

@app.get("/api/health")
async def health():
    return {"status": "healthy"}
```

### With Prompt Flow

1. Create new flow in Copilot Studio
2. Add **Python** node for `src/rag_agent.py`
3. Configure inputs/outputs
4. Connect to OpenAI and Search
5. Deploy

## Monitoring & Observability

### Application Insights

The agent automatically logs:
- Request count and latency
- Token usage (prompt + completion)
- Retrieved documents and sources
- Errors and exceptions
- User queries (PII redacted)

View in Azure Portal:
```
Application Insights → Logs → customEvents
| where name == "finops_query"
| summarize count(), sum(tokens) by bin(timestamp, 1h)
```

### Tracing

Enable detailed tracing:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## Cost Optimization Tips

### Reduce Token Costs

1. **Limit Retrieved Documents**: `TOP_K = 3` instead of 5
2. **Use GPT-4o-mini**: 70% cheaper than GPT-4o
3. **Enable Caching**: Cache system prompt
4. **Semantic Compression**: Summarize long documents

### Optimize Search Costs

1. **Use S1 tier**: Sufficient for most workloads
2. **Set TTL on documents**: Auto-cleanup old chunks
3. **Batch indexing**: Index in chunks of 100+

### Example Cost Estimate (Monthly)

| Component | Usage | Cost |
|-----------|-------|------|
| OpenAI (gpt-4o-mini) | 100K tokens/day | ~$30 |
| AI Search (S1) | 100GB storage | ~$250 |
| Azure Storage | 10GB documents | ~$0.25 |
| **Total** | | **~$280** |

## Security Best Practices

✅ **Authentication**
```bash
# Use Managed Identity (recommended)
az vm identity assign --ids /subscriptions/.../VM

# Or use Service Principal
export AZURE_CLIENT_ID="..."
export AZURE_CLIENT_SECRET="..."
export AZURE_TENANT_ID="..."
```

✅ **Secrets Management**
```bash
# Store in Key Vault
az keyvault secret set --vault-name MyKeyVault \
    --name AzureOpenAIKey --value $OPENAI_KEY

# Retrieve via code
from azure.keyvault.secrets import SecretClient
secret = client.get_secret("AzureOpenAIKey")
```

✅ **Network Security**
- Enable Azure AI Search private endpoint
- Use managed virtual network for Foundry
- Restrict Storage account access with firewall

## Troubleshooting

### Search Index Not Found

```bash
# Verify index exists
az search index list --service-name wolffFinopsAIsearch

# Recreate index
python -c "
from config import AzureConfig
from src.search_indexer import SearchIndexManager
config = AzureConfig()
manager = SearchIndexManager(config.SEARCH_ENDPOINT, config.SEARCH_API_KEY)
manager.delete_index(config.SEARCH_INDEX_NAME)
manager.create_index(config.SEARCH_INDEX_NAME, config.SEARCH_INDEX_SCHEMA)
"
```

### Embedding Generation Fails

```bash
# Check OpenAI quota and limits
az cognitiveservices account show --name wolffFinopsAI \
    --resource-group WolffFInopsAIrg \
    --query "properties.statuses"

# Verify deployment
az cognitiveservices account deployment list \
    --name wolffFinopsAI \
    --resource-group WolffFInopsAIrg
```

### Agent Returns Empty Results

```bash
# Check if documents are indexed
az search index statistics --service-name wolffFinopsAIsearch \
    --index-name finops-index

# Verify chunks were created
wc -l chunks.jsonl  # Should be > 0
```

## Next Steps

1. ✅ **Add Documents**: Copy FinOps PDFs/PPTs to knowledgebase folders
2. ✅ **Process**: Run `python -m src.document_processor`
3. ✅ **Index**: Run `python -m src.search_indexer`
4. ✅ **Test**: Run `python src/agent.py`
5. ✅ **Deploy**: Use Azure CLI or Portal
6. ✅ **Integrate**: Connect to Teams, web app, or Copilot Studio
7. ✅ **Monitor**: Enable Application Insights tracing
8. ✅ **Optimize**: Use Agent Optimizer for continuous improvement

## Advanced Features

### Custom Evaluators

Evaluate agent quality:
```bash
python -c "
from src.rag_agent import FinOpsAgent
from config import AzureConfig

agent = FinOpsAgent(AzureConfig())
results = agent.answer('How can we reduce cloud spending?')

# Evaluate: Does answer cite sources? Is it accurate?
has_sources = len(results['sources']) > 0
is_relevant = 'cost' in results['answer'].lower()
"
```

### Fine-tuning

Improve responses:
```bash
# Collect traces from production
# Use Agent Optimizer to fine-tune models
python -c "
from src.agent_optimizer import AgentOptimizer

optimizer = AgentOptimizer()
optimizer.load_traces('production_traces.jsonl')
optimizer.create_eval_dataset()
optimizer.fine_tune_model()
"
```

## Support & Contributing

- 📚 **Documentation**: See README sections above
- 🐛 **Issues**: Submit via GitHub Issues
- 💡 **Ideas**: Create Discussion threads
- 🤝 **Contributing**: See CONTRIBUTING.md

## License

MIT License - See LICENSE file

## References

- [Azure OpenAI Docs](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [Azure AI Search Docs](https://learn.microsoft.com/en-us/azure/search/)
- [Azure AI Foundry Docs](https://learn.microsoft.com/en-us/azure/ai-studio/)
- [FinOps Foundation](https://www.finops.org/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/architecture/framework/)

---

**Built with ❤️ for the Azure FinOps community**
