# Testing Guide - FinOps RAG Agent

Complete guide for testing all aspects of the FinOps RAG Agent.

## Pre-Flight Checks

### 1. Environment Setup

```bash
# Verify Python environment
python --version          # Should be 3.10+

# Check virtual environment
echo $VIRTUAL_ENV          # Should show venv path

# Verify dependencies
pip list | grep azure
pip list | grep openai
pip list | grep langchain
```

### 2. Azure Credentials

```bash
# Check Azure CLI login
az account show

# Verify subscription
az account set --subscription 5755893a-8056-4ba8-9916-1133c80a80f3

# Check resource access
az cognitiveservices account show --name wolffFinopsAI --resource-group WolffFInopsAIrg
az search service show --name wolffFinopsAIsearch --resource-group WolffFInopsAIrg
```

### 3. Environment Variables

```bash
# Check all required env vars are set
python -c "
import os
required = ['AZURE_OPENAI_KEY', 'AZURE_OPENAI_ENDPOINT', 'SEARCH_API_KEY', 'SEARCH_ENDPOINT']
for var in required:
    if var in os.environ:
        print(f'✓ {var}: {os.environ[var][:20]}...')
    else:
        print(f'✗ {var}: NOT SET')
"
```

---

## Unit Tests

### Test 1: Document Processing

```bash
python -c "
from src.document_processor import DocumentProcessor
import os

processor = DocumentProcessor()
print('✓ DocumentProcessor imported successfully')

# Check methods exist
assert hasattr(processor, 'process_pptx'), 'Missing process_pptx'
assert hasattr(processor, 'process_pdf'), 'Missing process_pdf'
assert hasattr(processor, 'process_directory'), 'Missing process_directory'
print('✓ All required methods exist')

# Verify configuration
from config import AzureConfig
config = AzureConfig()
assert config.CHUNK_SIZE == 1000, 'Invalid chunk size'
assert config.CHUNK_OVERLAP == 200, 'Invalid overlap'
print('✓ Configuration is correct')
"
```

### Test 2: Embedding Generation

```bash
python -c "
from src.search_indexer import EmbeddingGenerator
from config import AzureConfig

config = AzureConfig()
try:
    generator = EmbeddingGenerator(
        openai_endpoint=config.OPENAI_ENDPOINT,
        api_key=config.OPENAI_API_KEY,
        embedding_model=config.EMBEDDING_DEPLOYMENT
    )
    print('✓ EmbeddingGenerator initialized')
    
    # Test embedding generation
    test_text = 'Test sentence for embedding'
    embeddings = generator.generate_embeddings([test_text])
    
    assert len(embeddings) == 1, 'Expected 1 embedding'
    assert len(embeddings[0]) == 3072, f'Expected 3072 dimensions, got {len(embeddings[0])}'
    print(f'✓ Generated embedding with {len(embeddings[0])} dimensions')
    
except Exception as e:
    print(f'✗ Error: {e}')
    print('Check: AZURE_OPENAI_KEY and AZURE_OPENAI_ENDPOINT')
"
```

### Test 3: Search Index

```bash
python -c "
from src.search_indexer import SearchIndexManager
from config import AzureConfig

config = AzureConfig()
try:
    manager = SearchIndexManager(
        search_endpoint=config.SEARCH_ENDPOINT,
        api_key=config.SEARCH_API_KEY
    )
    print('✓ SearchIndexManager initialized')
    
    # Check if index exists
    from azure.search.documents import SearchClient
    from azure.core.credentials import AzureKeyCredential
    
    client = SearchClient(
        endpoint=config.SEARCH_ENDPOINT,
        index_name=config.SEARCH_INDEX_NAME,
        credential=AzureKeyCredential(config.SEARCH_API_KEY)
    )
    
    stats = client.get_search_statistics()
    print(f'✓ Index exists with {stats.document_count} documents')
    print(f'  Storage: {stats.storage_size} bytes')
    
except Exception as e:
    print(f'✗ Error: {e}')
    print('Check: SEARCH_ENDPOINT and SEARCH_API_KEY')
"
```

### Test 4: RAG Retriever

```bash
python -c "
from src.rag_agent import RAGRetriever
from config import AzureConfig

config = AzureConfig()
try:
    retriever = RAGRetriever(
        search_endpoint=config.SEARCH_ENDPOINT,
        api_key=config.SEARCH_API_KEY,
        index_name=config.SEARCH_INDEX_NAME,
        openai_endpoint=config.OPENAI_ENDPOINT,
        openai_key=config.OPENAI_API_KEY,
        embedding_model=config.EMBEDDING_DEPLOYMENT
    )
    print('✓ RAGRetriever initialized')
    
    # Test retrieval
    test_query = 'AKS cost optimization'
    results = retriever.retrieve(test_query, top_k=3)
    
    print(f'✓ Retrieved {len(results)} documents for test query')
    for doc in results[:1]:
        print(f'  - {doc[\"title\"][:50]}...')
        print(f'    Source: {doc[\"source\"]}')
    
except Exception as e:
    print(f'✗ Error: {e}')
    import traceback
    traceback.print_exc()
"
```

### Test 5: Agent Response

```bash
python -c "
from src.rag_agent import FinOpsAgent
from config import AzureConfig

config = AzureConfig()
try:
    agent = FinOpsAgent(config)
    print('✓ FinOpsAgent initialized')
    
    # Test query
    test_query = 'What is cloud cost optimization?'
    result = agent.answer(test_query, top_k=3)
    
    print(f'✓ Agent generated response')
    print(f'  Status: {\"success\" if result.get(\"answer\") else \"failed\"}')
    print(f'  Sources: {len(result.get(\"sources\", []))}')
    print(f'  Tokens: {result.get(\"usage\", {}).get(\"total_tokens\", \"N/A\")}')
    
    if result.get('answer'):
        preview = result['answer'][:100] + '...'
        print(f'  Preview: {preview}')
    
except Exception as e:
    print(f'✗ Error: {e}')
    import traceback
    traceback.print_exc()
"
```

---

## Integration Tests

### Test 6: Live Data Integration

```bash
python -c "
from src.azure_apis import FinOpsAzureAPIs
from config import AzureConfig

config = AzureConfig()
try:
    apis = FinOpsAzureAPIs(config.SUBSCRIPTION_ID)
    print('✓ FinOpsAzureAPIs initialized')
    
    # Test Cost Management
    daily_costs = apis.cost_mgmt.get_daily_costs(days=7)
    print('✓ Cost Management API connected')
    
    # Test Advisor
    advisor_recs = apis.advisor.get_cost_recommendations()
    print(f'✓ Advisor API: {len(advisor_recs)} recommendations')
    
    # Test Resource Graph
    vms = apis.resource_graph.get_vm_inventory()
    print(f'✓ Resource Graph: {len(vms)} VMs found')
    
    disks = apis.resource_graph.get_unattached_disks()
    print(f'✓ Unattached disks: {len(disks)}')
    
    ips = apis.resource_graph.get_public_ips()
    print(f'✓ Idle public IPs: {len(ips)}')
    
except Exception as e:
    print(f'✗ Error: {e}')
    print('Note: Some APIs may require specific RBAC roles')
"
```

### Test 7: Agent Handler

```bash
python -c "
from src.agent import FinOpsAgentHandler

try:
    handler = FinOpsAgentHandler()
    print('✓ FinOpsAgentHandler initialized')
    
    # Test RAG query
    response = handler.handle_message('How can we optimize costs?')
    assert response['status'] == 'success'
    assert response['response']
    print('✓ RAG query successful')
    
    # Test data request
    response = handler.handle_message('What is our current spending?')
    assert response['status'] == 'success'
    print('✓ Data request successful')
    
except Exception as e:
    print(f'✗ Error: {e}')
    import traceback
    traceback.print_exc()
"
```

---

## End-to-End Tests

### Test 8: Full Agent Workflow

```bash
# Run the agent with test queries
python -c "
from src.agent import FinOpsAgentHandler

queries = [
    'How can we optimize AKS costs?',
    'What are Reserved Instances?',
    'Show our resource inventory',
    'Check tagging compliance',
    'What are the top cost optimization opportunities?'
]

handler = FinOpsAgentHandler()

for query in queries:
    print(f'\n{'='*60}')
    print(f'Query: {query}')
    print('='*60)
    
    try:
        response = handler.handle_message(query)
        
        if response['status'] == 'success':
            print('✓ Response generated')
            print(f'\nAnswer (first 200 chars):')
            print(response['response'][:200] + '...')
            
            if response.get('sources'):
                print(f'\nSources: {response[\"sources\"]}')
        else:
            print(f'✗ Error: {response[\"response\"]}')
            
    except Exception as e:
        print(f'✗ Exception: {e}')
"
```

### Test 9: Document Processing Workflow

```bash
python -c "
import os
from pathlib import Path
from src.document_processor import DocumentProcessor, save_chunks_to_jsonl

# Check knowledge base
kb_path = Path('knowledgebase')
doc_count = 0
for category in kb_path.glob('*'):
    if category.is_dir():
        files = list(category.glob('*'))
        doc_count += len(files)
        print(f'📁 {category.name}: {len(files)} files')

if doc_count == 0:
    print('⚠️  No documents found. Add files to knowledgebase/ folders')
else:
    print(f'\n✓ Total documents: {doc_count}')
    
    # Process documents
    print('\nProcessing documents...')
    processor = DocumentProcessor()
    chunks = processor.process_directory('knowledgebase')
    
    print(f'✓ Generated {len(chunks)} chunks')
    
    # Save to JSONL
    save_chunks_to_jsonl(chunks, 'chunks_test.jsonl')
    print('✓ Saved chunks to chunks_test.jsonl')
    
    # Show sample
    if chunks:
        sample = chunks[0]
        print(f'\nSample chunk:')
        print(f'  ID: {sample[\"id\"]}')
        print(f'  Category: {sample[\"category\"]}')
        print(f'  Content preview: {sample[\"content\"][:100]}...')
"
```

---

## Performance Tests

### Test 10: Response Latency

```bash
python -c "
import time
from src.agent import FinOpsAgentHandler

handler = FinOpsAgentHandler()

queries = [
    'AKS cost optimization',
    'VM sizing recommendations',
    'Reserved Instances vs Savings Plans'
]

print('Testing response latency...\n')
latencies = []

for query in queries:
    start = time.time()
    response = handler.handle_message(query)
    elapsed = time.time() - start
    latencies.append(elapsed)
    
    print(f'Query: {query[:40]}...')
    print(f'  Latency: {elapsed:.2f}s')
    print(f'  Tokens: {response.get(\"usage\", {}).get(\"total_tokens\", \"N/A\")}')

avg_latency = sum(latencies) / len(latencies)
print(f'\nAverage latency: {avg_latency:.2f}s')
print(f'Target: < 3s (' + ('✓ PASS' if avg_latency < 3 else '✗ FAIL') + ')')
"
```

### Test 11: Concurrent Requests

```bash
python -c "
import asyncio
import time
from src.agent import FinOpsAgentHandler

async def test_concurrent():
    handler = FinOpsAgentHandler()
    
    queries = [
        'How to optimize costs?',
        'What is a reserved instance?',
        'VM sizing recommendations',
        'Governance best practices',
        'Cost forecast'
    ]
    
    print('Testing concurrent requests...\n')
    
    start = time.time()
    tasks = [asyncio.to_thread(handler.handle_message, q) for q in queries]
    results = await asyncio.gather(*tasks)
    elapsed = time.time() - start
    
    success = sum(1 for r in results if r['status'] == 'success')
    
    print(f'Requests: {len(queries)}')
    print(f'Success: {success}/{len(queries)}')
    print(f'Time: {elapsed:.2f}s')
    print(f'Result: ' + ('✓ PASS' if success == len(queries) else '✗ FAIL'))

asyncio.run(test_concurrent())
"
```

---

## Quality Tests

### Test 12: Response Quality

```bash
python -c "
from src.agent import FinOpsAgentHandler

handler = FinOpsAgentHandler()

test_cases = [
    {
        'query': 'AKS cost optimization',
        'should_contain': ['AKS', 'cost', 'Kubernetes'],
        'should_cite_sources': True
    },
    {
        'query': 'Reserved Instances',
        'should_contain': ['Reserved', 'instance', 'commitment'],
        'should_cite_sources': True
    },
    {
        'query': 'What is Azure?',
        'should_contain': ['Azure'],
        'should_cite_sources': False  # May have limited KB
    }
]

print('Testing response quality...\n')

for test in test_cases:
    response = handler.handle_message(test['query'])
    answer = response['response'].lower()
    
    print(f'Query: {test[\"query\"]}')
    
    # Check content
    found = sum(1 for word in test['should_contain'] if word.lower() in answer)
    print(f'  Content match: {found}/{len(test[\"should_contain\"])}')
    
    # Check sources
    has_sources = len(response.get('sources', [])) > 0
    expected_sources = test['should_cite_sources']
    
    if expected_sources and has_sources:
        print(f'  ✓ Sources cited')
    elif not expected_sources and not has_sources:
        print(f'  ✓ No sources expected')
    else:
        print(f'  ⚠️  Source expectation mismatch')
    
    print()
"
```

---

## Deployment Readiness Checklist

Run this comprehensive check:

```bash
python -c "
import os
import sys
from pathlib import Path

checks = {
    'Python Version': sys.version_info >= (3, 10),
    'Requirements Installed': all([
        __import__('azure'),
        __import__('openai'),
        __import__('langchain')
    ]),
    'Config File': Path('config.py').exists(),
    'Agent Code': Path('src/agent.py').exists(),
    'Environment Variables': all([
        'AZURE_OPENAI_KEY' in os.environ,
        'AZURE_OPENAI_ENDPOINT' in os.environ,
        'SEARCH_API_KEY' in os.environ,
        'SEARCH_ENDPOINT' in os.environ
    ]),
    'Knowledge Base': Path('knowledgebase').exists(),
    'Documentation': all([
        Path('README.md').exists(),
        Path('QUICKSTART.md').exists(),
        Path('DEPLOYMENT.md').exists()
    ]),
    'Deployment Config': Path('agent.yaml').exists(),
}

passed = 0
failed = 0

print('🔍 Deployment Readiness Checklist\n')

for check, result in checks.items():
    status = '✓' if result else '✗'
    passed += result
    failed += not result
    print(f'{status} {check}')

print(f'\nTotal: {passed} passed, {failed} failed')

if failed == 0:
    print('\n✅ Ready for deployment!')
else:
    print(f'\n⚠️  Fix {failed} issue(s) before deploying')
"
```

---

## Load Testing

```bash
pip install locust

# Create locustfile.py
cat > locustfile.py << 'EOF'
from locust import HttpUser, task, between
from src.agent import FinOpsAgentHandler

class FinOpsUser(HttpUser):
    wait_time = between(1, 3)
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.handler = FinOpsAgentHandler()
    
    @task(1)
    def ask_question(self):
        queries = [
            'How to optimize AKS?',
            'Reserved Instances',
            'Cost forecast'
        ]
        for query in queries:
            self.handler.handle_message(query)
EOF

# Run load test
locust -f locustfile.py --host http://localhost:8000 --users 10 --spawn-rate 2
```

---

## Troubleshooting Failed Tests

| Test | Failure | Solution |
|------|---------|----------|
| Embedding Generation | API key error | Check AZURE_OPENAI_KEY |
| Search Index | Index not found | Run: python -m src.search_indexer |
| RAG Retriever | No results | Add documents to knowledgebase/ |
| Agent Response | Empty response | Check API keys and network |
| Live Data | Auth error | Check Managed Identity RBAC |

---

## Summary

**Run all tests:**
```bash
bash -c '
echo "Running all tests..."
python tests/unit.py
python tests/integration.py
python tests/e2e.py
python tests/performance.py
echo "All tests complete!"
'
```

**Good luck! 🚀**
