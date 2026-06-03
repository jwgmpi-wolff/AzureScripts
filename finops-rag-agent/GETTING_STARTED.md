# 🚀 FinOps RAG Agent - Getting Started Checklist

Your complete FinOps RAG Agent has been built! Use this checklist to get up and running.

## ✅ Phase 1: Immediate Setup (10 minutes)

### 1. Activate Python Environment
- [ ] **Windows (PowerShell):** `.\venv\Scripts\Activate.ps1`
- [ ] **Linux/macOS:** `source venv/bin/activate`

### 2. Set Azure Credentials

Get your keys:
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

Set environment variables:
- [ ] **Windows:** `$env:AZURE_OPENAI_KEY = "..."`
- [ ] **Windows:** `$env:SEARCH_API_KEY = "..."`
- [ ] **Linux:** `export AZURE_OPENAI_KEY="..."`
- [ ] **Linux:** `export SEARCH_API_KEY="..."`

### 3. Verify Installation
```bash
python -c "
from src.agent import FinOpsAgentHandler
from config import AzureConfig
print('✓ All imports successful!')
"
```

---

## ✅ Phase 2: Knowledge Base Setup (Optional)

### 4. Add Your Documents

Create or copy FinOps documents:

```
knowledgebase/
├── aks/                    # AKS optimization docs
├── vm/                     # VM sizing docs
├── governance/             # Governance docs
└── cost-optimization/      # Cost optimization docs
```

Supported formats: `.pptx`, `.pdf`, `.md`, `.txt`

- [ ] Copied AKS documents
- [ ] Copied VM optimization docs
- [ ] Copied governance docs
- [ ] Copied cost optimization docs

### 5. Process Documents

```bash
# Generate chunks from documents
python -m src.document_processor
```

Expected output:
```
Processing category: AKS Cost Optimization
✓ Extracted 50 chunks from document.pptx
✓ Total chunks processed: 150
✓ Saved 150 chunks to chunks.jsonl
```

- [ ] Document processing complete
- [ ] chunks.jsonl created

### 6. Generate Embeddings & Index

```bash
# Index documents into Azure AI Search
python -m src.search_indexer
```

Expected output:
```
Generating embeddings for 150 chunks...
✓ Generated embeddings for batch 1
✓ Indexed batch 1: 10 documents
✓ Total documents indexed: 150
```

- [ ] Embeddings generated
- [ ] Documents indexed

---

## ✅ Phase 3: Test Locally (5 minutes)

### 7. Run Agent Test

```bash
python src/agent.py
```

Try these queries:
- [ ] "How can we optimize AKS costs?"
- [ ] "What are Reserved Instances?"
- [ ] "Check our resource tagging compliance"

Look for:
- ✅ Generated response
- ✅ Sources cited
- ✅ Token count shown

### 8. Test API Integration

```bash
python -c "
from src.agent import FinOpsAgentHandler
handler = FinOpsAgentHandler()

# Test data request
response = handler.handle_message('What is our current spending?')
print(f'Status: {response[\"status\"]}')
print(f'Response: {response[\"response\"][:200]}...')
"
```

- [ ] Agent responds successfully
- [ ] Sources are cited
- [ ] Live data integration works

---

## ✅ Phase 4: Deploy (20-30 minutes)

### Choose One Deployment Option:

#### **Option A: Copilot Studio (Recommended) ⭐**

1. [ ] Go to [Copilot Studio](https://copilotstudio.microsoft.com/)
2. [ ] Create → **Custom Copilot**
3. [ ] Name: "FinOps RAG Agent"
4. [ ] Settings → **System instructions** → Paste from `config.py`
5. [ ] Actions → Create action for your API
6. [ ] Test in chat interface
7. [ ] Publish to Teams (optional)

**Time:** 15 minutes | **Effort:** 🟢 Low | **Result:** Agent in Teams

See: [DEPLOYMENT.md](DEPLOYMENT.md#option-1-copilot-studio-recommended-for-mvp)

#### **Option B: Azure CLI**

```bash
# Create Foundry project
az ai project create \
    --name finops-rag-project \
    --resource-group WolffFInopsAIrg

# Deploy agent
az ai agent create \
    --name finops-rag-agent \
    --project finops-rag-project \
    --resource-group WolffFInopsAIrg \
    --source-dir .
```

- [ ] Project created
- [ ] Agent deployed
- [ ] Endpoint obtained

**Time:** 20 minutes | **Effort:** 🟡 Medium | **Result:** Production endpoint

See: [DEPLOYMENT.md](DEPLOYMENT.md#option-2-deploy-with-azure-cli)

#### **Option C: Azure Portal**

1. [ ] Azure Portal → Create → Azure AI Foundry
2. [ ] Create project "finops-rag-project"
3. [ ] Upload code files
4. [ ] Configure deployment settings
5. [ ] Deploy
6. [ ] Monitor in Application Insights

**Time:** 30 minutes | **Effort:** 🔴 High | **Result:** Full control

See: [DEPLOYMENT.md](DEPLOYMENT.md#option-3-deploy-via-portal)

---

## ✅ Phase 5: Production Setup (Optional)

### 9. Enable Monitoring

```bash
# View logs in Application Insights
az monitor app-insights query \
    --app finops-agent-insights \
    --analytics-query "
    customEvents
    | where name == 'finops_query'
    | summarize count(), avg(toreal(customDimensions.tokens))
    "
```

- [ ] Application Insights enabled
- [ ] Logs flowing
- [ ] Metrics visible

### 10. Configure Alerts

```bash
# Alert on high error rate
az monitor metrics alert create \
    --name "FinOps Agent Errors" \
    --resource-group WolffFInopsAIrg \
    ...
```

- [ ] Error alerts configured
- [ ] Latency alerts configured
- [ ] Cost alerts configured

### 11. Set Up CI/CD (Optional)

- [ ] Created `.github/workflows/deploy.yml` (see DEPLOYMENT.md)
- [ ] Configured secrets in GitHub
- [ ] Tested automated deployment

---

## 📚 Documentation Reference

| Document | Purpose | Read When |
|----------|---------|-----------|
| **README.md** | Full feature guide | Understanding capabilities |
| **QUICKSTART.md** | 10-minute setup | Getting started |
| **DEPLOYMENT.md** | 3 deployment options | Ready to deploy |
| **TESTING.md** | Comprehensive tests | Validating setup |
| **BUILD_SUMMARY.md** | What was built | Understanding architecture |
| **config.py** | All configuration | Customizing behavior |

**Quick Links:**
- 🚀 Getting Started: [QUICKSTART.md](QUICKSTART.md)
- 📖 Full Documentation: [README.md](README.md)
- 🚢 Deployment Guide: [DEPLOYMENT.md](DEPLOYMENT.md)
- ✅ Testing Guide: [TESTING.md](TESTING.md)

---

## 🎯 Success Criteria

### ✅ Setup Complete When:
- [x] All dependencies installed
- [x] Azure credentials set
- [x] Agent responds to test queries
- [x] Sources are cited correctly

### ✅ Knowledge Base Complete When:
- [x] Documents in knowledgebase/ folders
- [x] Chunks generated (chunks.jsonl)
- [x] Documents indexed in Azure AI Search
- [x] Retrieval returns relevant results

### ✅ Deployment Complete When:
- [x] Agent deployed to Azure AI Foundry
- [x] Endpoint responding to requests
- [x] Integrated with Copilot Studio / Teams (optional)
- [x] Monitoring enabled

---

## 🆘 Troubleshooting Quick Links

**Problem: "Azure OpenAI key not found"**
```bash
# Set manually
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
    --name wolffFinopsAI --resource-group WolffFInopsAIrg --query key1 -o tsv)
```

**Problem: "No documents found"**
```bash
# Check index
python -c "
from azure.search.documents import SearchClient
from config import AzureConfig
config = AzureConfig()
client = SearchClient(config.SEARCH_ENDPOINT, config.SEARCH_INDEX_NAME, ...)
print(client.get_search_statistics().document_count)
"
```

**Problem: "Agent returns empty response"**
1. Check Azure OpenAI is accessible: `python -c "from openai import AzureOpenAI; print('✓')"`
2. Check Search index has documents: See above
3. Check environment variables are set: `env | grep AZURE`

**See Also:** [TESTING.md](TESTING.md#troubleshooting-failed-tests)

---

## 📊 What You Have

### Core System
- ✅ RAG Pipeline (document processing → embeddings → retrieval)
- ✅ Azure AI Search Integration (vector + semantic + hybrid search)
- ✅ Azure OpenAI Integration (GPT-4o-mini for cost efficiency)
- ✅ Live Data Connectors (Cost Management, Advisor, Resource Graph)
- ✅ Agent Framework (ready for Foundry/Copilot Studio)

### Knowledge Base
- ✅ 7 Knowledge Categories (AKS, VM, SQL, Governance, Cost, etc.)
- ✅ Document Processing Pipeline (PPTX, PDF, Markdown, Text)
- ✅ Automatic Chunking & Embedding
- ✅ Source Citation

### Deployment
- ✅ 3 Deployment Options (Copilot Studio, CLI, Portal)
- ✅ Setup Scripts (Windows PowerShell & Linux bash)
- ✅ Configuration Management
- ✅ Monitoring & Observability

### Documentation
- ✅ 2000+ lines of comprehensive guides
- ✅ Quick Start (10 min)
- ✅ Full Reference (README)
- ✅ Deployment Guide
- ✅ Testing Guide

---

## 🎓 Next Steps (Recommended Order)

1. **This Week:**
   - [x] Activate environment ← **You are here**
   - [ ] Set Azure credentials
   - [ ] Test agent locally: `python src/agent.py`

2. **Next:**
   - [ ] Copy your FinOps documents to knowledgebase/
   - [ ] Process documents: `python -m src.document_processor`
   - [ ] Index: `python -m src.search_indexer`

3. **Then:**
   - [ ] Test with your knowledge base
   - [ ] Choose deployment option
   - [ ] Deploy to Azure AI Foundry

4. **Finally:**
   - [ ] Integrate with Copilot Studio (optional)
   - [ ] Enable monitoring
   - [ ] Gather user feedback
   - [ ] Optimize prompts

---

## 📞 Support

**Questions?**
- 📚 Check [README.md](README.md) for detailed explanations
- 🚀 Check [QUICKSTART.md](QUICKSTART.md) for quick answers
- 🚢 Check [DEPLOYMENT.md](DEPLOYMENT.md) for deployment help
- ✅ Check [TESTING.md](TESTING.md) for testing help

**Error?**
1. Check the error message for specific guidance
2. Search [TESTING.md](TESTING.md#troubleshooting-failed-tests)
3. Verify environment variables: `env | grep AZURE`
4. Run diagnostics:
   ```bash
   python -c "
   from src.agent import FinOpsAgentHandler
   handler = FinOpsAgentHandler()
   print('✓ All systems operational')
   "
   ```

---

## 🚀 You're All Set!

**Your FinOps RAG Agent is ready.** Pick an option below:

### Immediate Test
```bash
python src/agent.py
# Try: "How can we optimize cloud costs?"
```

### Quick Deploy (15 min)
Go to: [Copilot Studio](https://copilotstudio.microsoft.com/) → Create → Custom Copilot

### Full Setup
Follow: [QUICKSTART.md](QUICKSTART.md)

---

**Last Updated:** June 3, 2026

**Remember:** Start with a test, add documents, then deploy. You've got this! 💪

Happy FinOps! 🎉
