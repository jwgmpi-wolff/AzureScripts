# Quick Start Guide - FinOps RAG Agent

Get your FinOps RAG Agent up and running in 10 minutes!

## Prerequisites Check

```bash
# Verify you have the required tools
az --version              # Should be 2.50+
python --version          # Should be 3.10+
git --version             # Any version
```

## 5-Minute Setup

### 1. Activate Python Virtual Environment

**Windows (PowerShell):**
```powershell
.\venv\Scripts\Activate.ps1
```

**Linux/macOS:**
```bash
source venv/bin/activate
```

### 2. Set Environment Variables

**Windows (PowerShell):**
```powershell
$env:AZURE_OPENAI_KEY = "your-openai-key"
$env:AZURE_OPENAI_ENDPOINT = "https://wolfffinopsai.openai.azure.com/"
$env:SEARCH_API_KEY = "your-search-key"
$env:SEARCH_ENDPOINT = "https://wolfffinopsaisearch.search.windows.net"
```

**Linux/macOS:**
```bash
export AZURE_OPENAI_KEY="your-openai-key"
export AZURE_OPENAI_ENDPOINT="https://wolfffinopsai.openai.azure.com/"
export SEARCH_API_KEY="your-search-key"
export SEARCH_ENDPOINT="https://wolfffinopsaisearch.search.windows.net"
```

Get keys from:
```bash
# OpenAI key
az cognitiveservices account keys list \
    --name wolffFinopsAI \
    --resource-group WolffFInopsAIrg \
    --query key1 -o tsv

# Search key
az search admin-key show \
    --service-name wolffFinopsAIsearch \
    --resource-group WolffFInopsAIrg \
    --query primaryKey -o tsv
```

### 3. Add Sample Documents

Copy your FinOps documents (PPTX, PDF) to:
```
knowledgebase/
├── aks/                      # Copy AKS optimization docs here
├── vm/                       # VM sizing docs
├── governance/               # Governance docs
└── cost-optimization/        # General cost docs
```

**No documents yet?** That's fine! The agent will work with its built-in knowledge.

### 4. Process Documents (if you added any)

```bash
python -m src.document_processor
```

This will:
- Extract text from your documents
- Split into chunks
- Save to `chunks.jsonl`

### 5. Index Documents

```bash
python -m src.search_indexer
```

This will:
- Generate embeddings (may take 1-2 minutes)
- Index into Azure AI Search

### 6. Test Agent Locally

```bash
python src/agent.py
```

Expected output:
```
Query: How can we optimize AKS costs?
========================================
Answer: [RAG-powered response with recommendations]

Sources: AKS_Optimization.pdf
Tokens used: 1234
```

## Try These Sample Queries

```python
from src.agent import FinOpsAgentHandler

handler = FinOpsAgentHandler()

# Test 1: Basic optimization
response = handler.handle_message(
    "What are the top cost optimization opportunities for AKS?"
)
print(response["response"])

# Test 2: Live data
response = handler.handle_message(
    "What's our current spending trend and recommendations?"
)
print(response["response"])

# Test 3: Specific guidance
response = handler.handle_message(
    "Should we use Reserved Instances or Savings Plans?"
)
print(response["response"])
```

## Deploy in 5 More Minutes

### Option A: Deploy to Copilot Studio (Easiest)

1. Go to **[Copilot Studio](https://copilotstudio.microsoft.com/)**
2. Create **Custom Copilot**
3. Add system instructions from `config.py`
4. Configure action to call `src/agent.py`
5. **Publish to Teams** ✅

### Option B: Deploy with Azure CLI

```bash
# Create project
az ai project create \
    --name finops-rag-project \
    --resource-group WolffFInopsAIrg

# Deploy agent
az ai agent create \
    --name finops-rag-agent \
    --project finops-rag-project \
    --resource-group WolffFInopsAIrg \
    --source-dir .

# Get endpoint
ENDPOINT=$(az ai agent show \
    --name finops-rag-agent \
    --project finops-rag-project \
    --resource-group WolffFInopsAIrg \
    --query properties.endpoint -o tsv)

echo "Agent available at: $ENDPOINT"
```

## Common Tasks

### View Indexed Documents

```bash
python -c "
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential
from config import AzureConfig

config = AzureConfig()
client = SearchClient(
    endpoint=config.SEARCH_ENDPOINT,
    index_name=config.SEARCH_INDEX_NAME,
    credential=AzureKeyCredential(config.SEARCH_API_KEY)
)

stats = client.get_search_statistics()
print(f'📊 Documents indexed: {stats.document_count}')
print(f'Storage used: {stats.storage_size} bytes')
"
```

### Search Knowledge Base

```bash
python -c "
from src.rag_agent import RAGRetriever
from config import AzureConfig

config = AzureConfig()
retriever = RAGRetriever(
    search_endpoint=config.SEARCH_ENDPOINT,
    api_key=config.SEARCH_API_KEY,
    index_name=config.SEARCH_INDEX_NAME,
    openai_endpoint=config.OPENAI_ENDPOINT,
    openai_key=config.OPENAI_API_KEY,
    embedding_model=config.EMBEDDING_DEPLOYMENT
)

results = retriever.retrieve('AKS cost optimization', top_k=3)
for doc in results:
    print(f'📄 {doc[\"title\"]}')
    print(f'   Source: {doc[\"source\"]}')
    print()
"
```

### View Agent Logs

```bash
# Enable debug logging
python -c "
import logging
logging.basicConfig(level=logging.DEBUG)

from src.agent import FinOpsAgentHandler
handler = FinOpsAgentHandler()
response = handler.handle_message('Test query')
"
```

### Check Azure Resources

```bash
# Check OpenAI
az cognitiveservices account show \
    --name wolffFinopsAI \
    --resource-group WolffFInopsAIrg

# Check Search
az search service show \
    --name wolffFinopsAIsearch \
    --resource-group WolffFInopsAIrg

# Check Storage (for documents)
az storage account show \
    --name <your-storage> \
    --resource-group WolffFInopsAIrg
```

## Troubleshooting

### "Azure OpenAI key not set"

```bash
# Get key
KEY=$(az cognitiveservices account keys list \
    --name wolffFinopsAI \
    --resource-group WolffFInopsAIrg \
    --query key1 -o tsv)

# Set it
export AZURE_OPENAI_KEY=$KEY
```

### "No documents found"

Check if documents were indexed:

```bash
# View document count
python -c "
from azure.search.documents import SearchClient
from azure.core.credentials import AzureKeyCredential
from config import AzureConfig
config = AzureConfig()
client = SearchClient(config.SEARCH_ENDPOINT, config.SEARCH_INDEX_NAME, AzureKeyCredential(config.SEARCH_API_KEY))
print(client.get_search_statistics().document_count)
"

# If 0, re-index:
python -m src.search_indexer
```

### "API rate limited"

The agent is being called too frequently. Check:

```bash
# View Application Insights metrics
az monitor app-insights metrics show \
    --app finops-agent-insights \
    --metric requests/sec \
    --interval PT1M
```

## Next Steps

1. ✅ **Add More Documents**: Expand knowledgebase folders with your docs
2. ✅ **Optimize Prompts**: Edit `config.py` FINOPS_SYSTEM_PROMPT
3. ✅ **Deploy**: Follow deployment guide
4. ✅ **Monitor**: Enable Application Insights
5. ✅ **Iterate**: Gather user feedback, improve

## File Reference

| File | Purpose |
|------|---------|
| `config.py` | Configuration and system prompt |
| `src/agent.py` | Main agent entry point |
| `src/rag_agent.py` | RAG retrieval system |
| `src/document_processor.py` | Process documents to chunks |
| `src/search_indexer.py` | Index into AI Search |
| `src/azure_apis.py` | Cost Management API integration |
| `agent.yaml` | Foundry agent config |
| `requirements.txt` | Python dependencies |

## Support

- 📖 Full docs: See [README.md](README.md)
- 🚀 Deployment: See [DEPLOYMENT.md](DEPLOYMENT.md)
- 🆘 Issues: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Ready? Start with:** `python src/agent.py` 🚀
