"""
FinOps RAG Agent Configuration
"""
import os
from dataclasses import dataclass

@dataclass
class AzureConfig:
    """Azure service configuration"""
    SUBSCRIPTION_ID: str = "5755893a-8056-4ba8-9916-1133c80a80f3"
    RESOURCE_GROUP: str = "WolffFInopsAIrg"
    
    # Azure OpenAI Configuration
    OPENAI_RESOURCE_NAME: str = "wolffFinopsAI"
    OPENAI_API_KEY: str = os.getenv("AZURE_OPENAI_KEY", "")
    OPENAI_ENDPOINT: str = os.getenv("AZURE_OPENAI_ENDPOINT", f"https://{OPENAI_RESOURCE_NAME}.openai.azure.com/")
    OPENAI_API_VERSION: str = "2024-02-15-preview"
    
    # Models
    CHAT_MODEL: str = "gpt-4o-mini"
    CHAT_DEPLOYMENT: str = "gpt-4o-mini"
    EMBEDDING_MODEL: str = "text-embedding-3-large"
    EMBEDDING_DEPLOYMENT: str = "text-embedding-3-large"
    
    # Azure AI Search Configuration
    SEARCH_SERVICE_NAME: str = "wolffFinopsAIsearch"
    SEARCH_API_KEY: str = os.getenv("SEARCH_API_KEY", "")
    SEARCH_ENDPOINT: str = os.getenv("SEARCH_ENDPOINT", f"https://{SEARCH_SERVICE_NAME}.search.windows.net")
    SEARCH_INDEX_NAME: str = "finops-index"
    SEARCH_API_VERSION: str = "2024-07-01"
    
    # Azure AI Foundry
    FOUNDRY_PROJECT_NAME: str = "finops-rag-project"
    FOUNDRY_HUB_NAME: str = "finops-hub"
    
    # Knowledge Base
    KB_DIR: str = "./knowledgebase"
    CHUNK_SIZE: int = 1000
    CHUNK_OVERLAP: int = 200
    
    # Retrieval Settings
    TOP_K: int = 5
    SIMILARITY_THRESHOLD: float = 0.7
    
    # Cost Management APIs
    COST_MGMT_API_VERSION: str = "2023-11-01"
    ADVISOR_API_VERSION: str = "2023-01-01"


# System Prompt for FinOps Agent
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
- Mention RI/Savings Plan opportunities when applicable
- Recommend governance improvements for cost control
- Always cite the source of recommendations
- Never fabricate pricing data or statistics
- Flag uncertain recommendations clearly

Response Format:
- Executive Summary (1-2 sentences)
- Technical Recommendation(s)
- Estimated Savings/Impact
- Implementation Steps
- Risk Level (Low/Medium/High)
- Next Steps
- Source(s)

When analyzing costs:
1. Ask clarifying questions about workload characteristics
2. Review current resource configuration
3. Check for right-sizing opportunities
4. Identify orphaned or underutilized resources
5. Suggest commitment-based discounts
6. Recommend automation and monitoring improvements
"""

# Search Index Schema
SEARCH_INDEX_SCHEMA = {
    "name": "finops-index",
    "fields": [
        {
            "name": "id",
            "type": "Edm.String",
            "key": True,
            "filterable": True
        },
        {
            "name": "content",
            "type": "Edm.String",
            "searchable": True,
            "retrievable": True
        },
        {
            "name": "contentVector",
            "type": "Collection(Edm.Single)",
            "searchable": True,
            "retrievable": True,
            "dimensions": 3072,
            "vectorSearchProfile": "vector-profile"
        },
        {
            "name": "source",
            "type": "Edm.String",
            "filterable": True,
            "retrievable": True
        },
        {
            "name": "category",
            "type": "Edm.String",
            "filterable": True,
            "retrievable": True
        },
        {
            "name": "title",
            "type": "Edm.String",
            "searchable": True,
            "retrievable": True
        },
        {
            "name": "metadata",
            "type": "Edm.String",
            "retrievable": True
        }
    ],
    "vectorSearch": {
        "algorithms": [
            {
                "name": "hnsw",
                "kind": "hnsw",
                "parameters": {
                    "m": 4,
                    "efConstruction": 400,
                    "efSearch": 500,
                    "metric": "cosine"
                }
            }
        ],
        "profiles": [
            {
                "name": "vector-profile",
                "algorithm": "hnsw",
                "vectorizer": "openai"
            }
        ],
        "vectorizers": [
            {
                "name": "openai",
                "kind": "azureOpenAI",
                "azureOpenAIParameters": {
                    "resourceUri": "${OPENAI_ENDPOINT}",
                    "deploymentId": "${EMBEDDING_DEPLOYMENT}",
                    "apiKey": "${OPENAI_API_KEY}",
                    "modelName": "${EMBEDDING_MODEL}"
                }
            }
        ]
    },
    "semantic": {
        "configurations": [
            {
                "name": "default",
                "prioritizedFields": {
                    "titleField": {
                        "fieldName": "title"
                    },
                    "contentFields": [
                        {
                            "fieldName": "content"
                        }
                    ],
                    "keywordsFields": [
                        {
                            "fieldName": "category"
                        }
                    ]
                }
            }
        ]
    }
}
