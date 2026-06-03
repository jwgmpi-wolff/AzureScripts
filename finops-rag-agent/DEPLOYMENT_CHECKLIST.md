# Azure AI Foundry Deployment Checklist

**Project Name:** finops-rag-project  
**Agent Name:** finops-rag-agent  
**Region:** eastus2  
**Subscription:** wolffentpSub (5755893a-8056-4ba8-9916-1133c80a80f3)  

---

## STEP 1: Create Foundry Project ⏱️ 3-5 min
- [ ] Open https://ai.azure.com
- [ ] Sign in with your Azure account
- [ ] Click "New Project"
- [ ] Name: `finops-rag-project`
- [ ] Resource Group: `WolffFInopsAIrg`
- [ ] Region: `eastus2`
- [ ] Click "Create" and wait for completion

---

## STEP 2: Create Agent ⏱️ 1-2 min
- [ ] In project, click "Agents" in sidebar
- [ ] Click "New Agent" or "Create Agent"
- [ ] Name: `finops-rag-agent`
- [ ] Model: `gpt-4o-mini`
- [ ] Click "Create"

---

## STEP 3: Configure System Instructions ⏱️ 2 min
- [ ] Open agent editor
- [ ] Find "System Instructions" field
- [ ] Clear default text
- [ ] Paste system prompt (from deploy.py output or below)
- [ ] Click "Save"

**System Prompt:**
```
You are an expert Azure FinOps assistant specializing in cloud cost 
optimization, governance, and best practices.

Your role:
- Provide actionable cost optimization recommendations based on Azure 
  best practices
- Analyze current resource configurations and spending patterns  
- Recommend Reserved Instances (RI) and Savings Plan opportunities
- Guide on proper governance, tagging, and policy implementation
- Cite all recommendations with sources from the knowledge base

Rules:
- Only answer using retrieved FinOps knowledge base documents
- Prioritize Azure cost optimization best practices
- Never fabricate pricing data or statistics
- Flag uncertain recommendations clearly
- Always cite sources from retrieved documents
```

---

## STEP 4: Enable Knowledge Base Integration ⏱️ 2-3 min
- [ ] In agent editor, find "Tools" or "Actions" section
- [ ] Enable "Code Interpreter" (for data analysis)
- [ ] Add "Retrieval" tool:
  - [ ] Click "Add Tool" → "Retrieval"
  - [ ] Search Service: `wolffFinopsAIsearch`
  - [ ] Index Name: `finops-index`
- [ ] Click "Save"

---

## STEP 5: Deploy Agent as Endpoint ⏱️ 5-10 min
- [ ] In agent editor, click "Deploy" or "Deploy Agent"
- [ ] Select deployment type: "Managed"
- [ ] Instance type: "Standard"
- [ ] Auto-scale: 1-3 instances
- [ ] Endpoint type: "REST"
- [ ] Click "Deploy"
- [ ] Monitor deployment status in notification panel
- [ ] **Wait for completion** (usually 5-10 minutes)

---

## STEP 6: Get Your Endpoint Details ⏱️ 1 min
Once deployment is complete:
- [ ] Go to "Endpoints" section
- [ ] Copy endpoint URL (looks like: `https://...api.cognitive.microsoft.com/openai/deployments/finops-rag-agent/...`)
- [ ] Note: `__ENDPOINT_URL__` = ________________
- [ ] Copy API Key from "Keys and Endpoints" section
- [ ] Note: `__API_KEY__` = ________________

---

## STEP 7: Test Your Agent ⏱️ 2-3 min
- [ ] In Foundry project, click "Test Agent" or "Try It"
- [ ] Type a test query:
  - "How can we reduce Azure costs?"
  - "What are cost optimization best practices?"
- [ ] Agent should respond with recommendations
- [ ] ✅ If successful, agent is working!

---

## STEP 8 (Optional): Integrate with Copilot Studio
If you want to use the agent in Copilot Studio/Teams:
- [ ] Go to https://copilotstudio.microsoft.com/
- [ ] Create copilot or edit existing one
- [ ] Add "Action" → "Call a web service"
- [ ] Enter your Foundry endpoint URL (from STEP 6)
- [ ] Test in Copilot Studio

---

## STEP 9: Upload Your Knowledge Base ⏱️ 2-5 min
After deployment succeeds, populate with documents:

```powershell
cd c:\.git\AzureScripts\finops-rag-agent

# Process your documents (PPTX, PDF, MD, TXT)
python -m src.document_processor

# Generate embeddings and index into Azure AI Search
python -m src.search_indexer
```

- [ ] Place your PPTX/PDF files in `knowledgebase/` folder
- [ ] Run document processor
- [ ] Run search indexer
- [ ] Index should now contain your documents

---

## STEP 10: Test with Your Documents ⏱️ 2-3 min
- [ ] Return to Foundry test panel
- [ ] Ask questions about your documents:
  - "What does the document say about [topic]?"
  - "Based on our documents, recommend cost optimizations"
- [ ] Agent should cite sources from your knowledge base
- [ ] ✅ Complete!

---

## Summary

| Step | Task | Time | Status |
|------|------|------|--------|
| 1 | Create Foundry Project | 3-5 min | ⬜ |
| 2 | Create Agent | 1-2 min | ⬜ |
| 3 | System Instructions | 2 min | ⬜ |
| 4 | Knowledge Base Tools | 2-3 min | ⬜ |
| 5 | Deploy Endpoint | 5-10 min | ⬜ |
| 6 | Get Endpoint Details | 1 min | ⬜ |
| 7 | Test Agent | 2-3 min | ⬜ |
| 8 | Copilot Integration (optional) | 5 min | ⬜ |
| 9 | Upload Documents | 2-5 min | ⬜ |
| 10 | Test with Docs | 2-3 min | ⬜ |
| **TOTAL** | **All Steps** | **~30 min** | ✅ |

---

## Quick Reference

**Project Structure:**
```
c:\.git\AzureScripts\finops-rag-agent\
├── src/
│   ├── agent.py                 # Main agent logic
│   ├── rag_agent.py             # RAG retrieval engine
│   ├── config.py                # Configuration (all set!)
│   ├── azure_apis.py            # Cost/Advisor/Graph APIs
│   └── document_processor.py    # Document processing
├── knowledgebase/               # Your documents go here
├── requirements.txt             # Python dependencies
├── agent.yaml                   # Foundry agent config
└── deploy.py                    # This deployment script
```

**Key Resources:**
- 🔗 Foundry Portal: https://ai.azure.com
- 🔗 Copilot Studio: https://copilotstudio.microsoft.com/
- 📖 Full Guide: See README.md
- 📋 All Deploy Options: See DEPLOYMENT.md
- 🧪 Testing Guide: See TESTING.md

---

## Troubleshooting Quick Links

| Problem | Solution |
|---------|----------|
| "Deployment timed out" | Check Portal → refresh → may take 10-15 min |
| "Index not found" | Run `python -m src.search_indexer` first |
| "API Key error" | Copy from Portal → Keys and Endpoints section |
| "Generic responses" | Enable Knowledge Base tool in agent settings |
| "Documents not found" | Run document processor & search indexer |

---

**Status:** Ready to deploy! 🚀

Start with **STEP 1** above →
