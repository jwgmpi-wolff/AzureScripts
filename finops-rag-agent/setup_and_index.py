#!/usr/bin/env python3
"""
Setup Azure credentials and run document indexing
Run this after creating the Azure OpenAI and Search resources
"""

import os
import sys
import subprocess

def prompt_for_credentials():
    """Prompt user for Azure credentials and set environment variables"""
    
    print("""
╔════════════════════════════════════════════════════════════════════════════╗
║          Setup FinOps RAG Agent - Azure Credentials                        ║
╚════════════════════════════════════════════════════════════════════════════╝

Follow these steps to get your API keys:

AZURE OPENAI KEY:
1. Go to Azure Portal → wolffFinopsAI resource
2. Click "Keys and Endpoints" (left sidebar)
3. Copy "Key 1" or "Key 2"

AZURE SEARCH KEY:
1. Go to Azure Portal → wolffFinopsAIsearch resource
2. Click "Keys" (left sidebar)
3. Copy "Primary admin key"

────────────────────────────────────────────────────────────────────────────

""")
    
    # Get Azure OpenAI Key
    openai_key = input("Enter your Azure OpenAI API Key (Key 1 or Key 2): ").strip()
    if not openai_key:
        print("❌ OpenAI key is required")
        sys.exit(1)
    
    # Get Azure Search Key
    search_key = input("Enter your Azure AI Search API Key (Primary admin key): ").strip()
    if not search_key:
        print("❌ Search key is required")
        sys.exit(1)
    
    return openai_key, search_key


def set_environment_variables(openai_key, search_key):
    """Set environment variables for the indexing process"""
    
    os.environ['AZURE_OPENAI_KEY'] = openai_key
    os.environ['AZURE_OPENAI_ENDPOINT'] = 'https://wolffFinopsAI.openai.azure.com/'
    os.environ['SEARCH_API_KEY'] = search_key
    os.environ['SEARCH_ENDPOINT'] = 'https://wolffFinopsAIsearch.search.windows.net'
    
    print("\n✓ Environment variables set")
    return True


def run_indexer():
    """Run the search indexer to process and index documents"""
    
    print("\n" + "="*80)
    print("Indexing 29 document chunks into Azure AI Search...")
    print("="*80 + "\n")
    
    try:
        # Import and run the indexer
        from src.search_indexer import (
            SearchIndexManager, DocumentIndexer, load_chunks_from_jsonl
        )
        from config import AzureConfig
        
        config = AzureConfig()
        
        print("Loading document chunks from chunks.jsonl...")
        chunks = load_chunks_from_jsonl("chunks.jsonl")
        print(f"✓ Loaded {len(chunks)} chunks")
        
        if len(chunks) == 0:
            print("⚠️  No chunks found. Run: python -m src.document_processor")
            return False
        
        print(f"\nIndexing into Azure AI Search ({config.SEARCH_INDEX_NAME})...")
        
        # Create indexer and index documents
        indexer = DocumentIndexer(
            search_endpoint=config.SEARCH_ENDPOINT,
            api_key=config.SEARCH_API_KEY,
            openai_endpoint=config.OPENAI_ENDPOINT,
            openai_key=config.OPENAI_API_KEY,
            embedding_model=config.EMBEDDING_DEPLOYMENT,
            index_name=config.SEARCH_INDEX_NAME
        )
        
        total = indexer.index_documents(chunks)
        
        print(f"\n✅ Successfully indexed {total} documents!")
        print(f"\nYour knowledge base is now ready:")
        print(f"  - Index: {config.SEARCH_INDEX_NAME}")
        print(f"  - Service: {config.SEARCH_SERVICE_NAME}")
        print(f"  - Documents: {total}")
        
        return True
        
    except Exception as e:
        print(f"\n❌ Indexing failed: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main entry point"""
    
    print("\n🚀 FinOps RAG Agent - Setup & Indexing\n")
    
    # Prompt for credentials
    openai_key, search_key = prompt_for_credentials()
    
    # Set environment variables
    set_environment_variables(openai_key, search_key)
    
    # Run indexer
    success = run_indexer()
    
    if success:
        print(f"""
╔════════════════════════════════════════════════════════════════════════════╗
║                          NEXT STEPS                                        ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                            ║
║  1. Deploy agent to Azure AI Foundry:                                      ║
║     → Open https://ai.azure.com                                            ║
║     → Follow the 8 steps from: python deploy.py                            ║
║                                                                            ║
║  2. Your knowledge base is indexed and ready!                              ║
║     Documents will be retrieved when users ask questions.                  ║
║                                                                            ║
║  3. For Copilot Studio integration (optional):                             ║
║     → See DEPLOYMENT.md "Option 1: Copilot Studio"                         ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
""")
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
