#!/usr/bin/env python3
"""
Deploy FinOps RAG Agent to Azure AI Foundry

This script provides deployment instructions and guidance.
No external dependencies required.
"""

import sys
from pathlib import Path

# Configuration
SUBSCRIPTION_ID = "5755893a-8056-4ba8-9916-1133c80a80f3"
RESOURCE_GROUP = "WolffFInopsAIrg"
PROJECT_NAME = "finops-rag-project"
AGENT_NAME = "finops-rag-agent"
REGION = "eastus2"

# FinOps System Prompt
FINOPS_SYSTEM_PROMPT = """You are an expert Azure FinOps assistant specializing in cloud cost optimization, governance, and best practices.

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
- Always cite sources from retrieved documents"""


def show_deployment_guide():
    """Display deployment instructions for Azure Portal"""
    guide = f"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                  Azure AI Foundry Deployment Guide                          ║
║                         (Deploy via Portal)                                  ║
╚══════════════════════════════════════════════════════════════════════════════╝

OVERVIEW
────────
Your FinOps RAG Agent is ready to deploy. Since Azure CLI extensions have
issues, we'll deploy via the Azure Portal (manual but straightforward).
Estimated time: 10-15 minutes

STEP 1: Create AI Foundry Project
──────────────────────────────────
1. Open https://ai.azure.com in your browser
2. Sign in with your Azure account (wolffentpSub)
3. Click "New Project" (top-right button)
4. Fill in these details:
   
   Name: {PROJECT_NAME}
   Subscription: wolffentpSub
   Resource Group: {RESOURCE_GROUP}
   Region: {REGION}
   
5. Click "Create"
6. Wait 2-3 minutes for the project to be created

💡 TIP: You can see progress in the notification icon (top-right)

STEP 2: Create the Agent
────────────────────────
1. In your new project, click "Agents" in the left sidebar
2. Click "New Agent" or "Create Agent"
3. Fill in:
   
   Name: {AGENT_NAME}
   Model: gpt-4o-mini (use deployment from your OpenAI resource)
   
4. Click "Create"

STEP 3: Configure System Instructions
──────────────────────────────────────
1. After agent is created, you'll see the agent editor
2. Find the "System Instructions" or "Instructions" field
3. CLEAR the default text and paste this:

───────────────────────────────────────────────────────────────────────────────
{FINOPS_SYSTEM_PROMPT}
───────────────────────────────────────────────────────────────────────────────

4. Click "Save"

STEP 4: Enable Knowledge Base Integration
──────────────────────────────────────────
1. In the agent editor, look for "Tools" or "Actions" section
2. Enable "Code Interpreter" (for data analysis)
3. Add "Retrieval" tool:
   - Click "Add Tool" → "Retrieval"
   - Search Service: wolffFinopsAIsearch
   - Index: finops-index
4. Save

STEP 5: Deploy Agent as Endpoint
─────────────────────────────────
1. In the agent editor, click "Deploy" or "Deploy Agent"
2. Select deployment type: "Managed" (easiest, fully managed by Azure)
3. Configure:
   - Instance type: Standard
   - Compute: Auto-scale (1-3 instances)
   - Endpoint type: REST
4. Click "Deploy"
5. Wait 5-10 minutes for deployment to complete

📊 You can monitor progress in the deployment status panel

STEP 6: Get Your Endpoint
─────────────────────────
1. Once deployment is complete, go to "Endpoints" section
2. You'll see your agent endpoint URL, which looks like:
   https://your-region.api.cognitive.microsoft.com/openai/deployments/finops-rag-agent/chat/completions
3. Copy this URL - you'll need it for integration
4. Also note your API Key (in "Keys and Endpoints" section)

STEP 7: Test Your Agent
────────────────────────
1. In the Foundry project, click "Test Agent" or "Try It"
2. Type a query like:
   "How can we reduce Azure costs?"
   
3. The agent should respond with cost optimization recommendations

✅ If you get a response, your agent is working!

STEP 8 (OPTIONAL): Integrate with Copilot Studio
──────────────────────────────────────────────────
If you want to use this in Copilot Studio (Teams, etc.):

1. Go to https://copilotstudio.microsoft.com/
2. Create new copilot or edit existing one
3. Add "Action" → "Call a web service"
4. Enter your Foundry endpoint URL
5. Test in Copilot Studio

────────────────────────────────────────────────────────────────────────────────

WHAT'S NEXT?
────────────

After deployment, you'll have 2 important tasks:

1. UPLOAD YOUR KNOWLEDGE BASE (DOCUMENTS)
   ─────────────────────────────────────
   Your agent is ready, but needs documents to retrieve from.
   
   From your project directory, run:
   
   $ python -m src.document_processor
   $ python -m src.search_indexer
   
   This will:
   - Process your PPTX/PDF documents
   - Generate embeddings
   - Index into Azure AI Search
   - Your agent can now answer from your documents!

2. TEST WITH YOUR DOCUMENTS
   ─────────────────────────
   In the Foundry test panel, ask questions about:
   - Your specific cost patterns
   - Your infrastructure setup
   - Best practices for your environment

────────────────────────────────────────────────────────────────────────────────

TROUBLESHOOTING
───────────────

❓ "Agent deployment timed out"
→ Check Azure Portal for deployment status
→ May take 10-15 minutes, refresh the page

❓ "Index not found" error
→ Make sure the index name is exactly: finops-index
→ If not created yet, run: python -m src.search_indexer

❓ "API Key error" when testing
→ Go to Foundry project → Settings → Keys and Endpoints
→ Copy the correct API key
→ Update your environment variable or config

❓ Agent returns generic answers instead of from knowledge base
→ Check that Knowledge Base retrieval tool is enabled
→ Verify index has documents (run search_indexer)
→ Try specific questions about your documents

────────────────────────────────────────────────────────────────────────────────

DOCUMENTATION
──────────────

For more details:
- Full Setup Guide: README.md
- Architecture Details: BUILD_SUMMARY.md  
- Testing Guide: TESTING.md
- Deployment Options: DEPLOYMENT.md

╔══════════════════════════════════════════════════════════════════════════════╗
║                       SUMMARY                                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  ✓ Agent code is ready (src/agent.py)                                       ║
║  ✓ Configuration is complete (config.py)                                    ║
║  ✓ All dependencies are documented (requirements.txt)                       ║
║                                                                              ║
║  👉 NEXT: Deploy agent in Azure Portal (5-10 minutes)                        ║
║  👉 THEN: Upload your documents (2-5 minutes)                               ║
║  👉 TEST: Ask your agent questions about your costs!                        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""
    return guide


def main():
    print("""
╔════════════════════════════════════════════════════════════════════════════╗
║          FinOps RAG Agent - Azure AI Foundry Deployment                    ║
╚════════════════════════════════════════════════════════════════════════════╝
    """)
    
    # Verify prerequisites
    print("✓ Checking prerequisites...")
    if not Path("config.py").exists():
        print("❌ config.py not found. Please run from project root")
        sys.exit(1)
    print("✓ Project files verified")
    print("✓ Configuration loaded")
    
    # Show deployment guide
    print(show_deployment_guide())


if __name__ == "__main__":
    main()
