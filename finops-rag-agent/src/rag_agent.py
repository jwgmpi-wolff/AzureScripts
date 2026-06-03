"""
RAG Retrieval System and Response Generation
"""
import logging
from typing import List, Dict, Any, Tuple
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from azure.core.credentials import AzureKeyCredential
from openai import AzureOpenAI
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class RAGRetriever:
    """Retrieve relevant documents from Azure AI Search"""
    
    def __init__(self, search_endpoint: str, api_key: str, index_name: str,
                 openai_endpoint: str, openai_key: str, embedding_model: str):
        self.search_client = SearchClient(
            endpoint=search_endpoint,
            index_name=index_name,
            credential=AzureKeyCredential(api_key)
        )
        self.openai_client = AzureOpenAI(
            api_key=openai_key,
            api_version="2024-02-15-preview",
            azure_endpoint=openai_endpoint
        )
        self.embedding_model = embedding_model
    
    def _generate_query_embedding(self, query: str) -> List[float]:
        """Generate embedding for query"""
        response = self.openai_client.embeddings.create(
            input=query,
            model=self.embedding_model
        )
        return response.data[0].embedding
    
    def retrieve(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """Retrieve relevant documents using hybrid search (vector + semantic + lexical)"""
        logger.info(f"Retrieving documents for query: {query}")
        
        # Generate query embedding
        query_embedding = self._generate_query_embedding(query)
        vector_query = VectorizedQuery(vector=query_embedding, k_nearest_neighbors=top_k, fields="contentVector")
        
        # Perform hybrid search
        try:
            results = self.search_client.search(
                search_text=query,
                vector_queries=[vector_query],
                select=["id", "content", "source", "category", "title", "metadata"],
                top=top_k,
                query_type="semantic",
                semantic_configuration="default"
            )
            
            documents = []
            for result in results:
                doc = {
                    "id": result.get("id"),
                    "content": result.get("content"),
                    "source": result.get("source"),
                    "category": result.get("category"),
                    "title": result.get("title"),
                    "score": result.get("@search.score", 0)
                }
                documents.append(doc)
            
            logger.info(f"✓ Retrieved {len(documents)} relevant documents")
            return documents
            
        except Exception as e:
            logger.error(f"Error retrieving documents: {e}")
            return []
    
    def retrieve_by_category(self, query: str, category: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """Retrieve documents filtered by category"""
        logger.info(f"Retrieving documents for query: {query} (category: {category})")
        
        query_embedding = self._generate_query_embedding(query)
        vector_query = VectorizedQuery(vector=query_embedding, k_nearest_neighbors=top_k, fields="contentVector")
        
        try:
            results = self.search_client.search(
                search_text=query,
                vector_queries=[vector_query],
                filter=f"category eq '{category}'",
                select=["id", "content", "source", "category", "title"],
                top=top_k
            )
            
            documents = [dict(result) for result in results]
            logger.info(f"✓ Retrieved {len(documents)} documents from category '{category}'")
            return documents
            
        except Exception as e:
            logger.error(f"Error retrieving documents: {e}")
            return []


class FinOpsAgent:
    """FinOps RAG Agent for cost optimization recommendations"""
    
    def __init__(self, config):
        self.config = config
        self.retriever = RAGRetriever(
            search_endpoint=config.SEARCH_ENDPOINT,
            api_key=config.SEARCH_API_KEY,
            index_name=config.SEARCH_INDEX_NAME,
            openai_endpoint=config.OPENAI_ENDPOINT,
            openai_key=config.OPENAI_API_KEY,
            embedding_model=config.EMBEDDING_DEPLOYMENT
        )
        self.openai_client = AzureOpenAI(
            api_key=config.OPENAI_API_KEY,
            api_version=config.OPENAI_API_VERSION,
            azure_endpoint=config.OPENAI_ENDPOINT
        )
    
    def _format_context(self, documents: List[Dict[str, Any]]) -> str:
        """Format retrieved documents as context"""
        context = "# Retrieved Knowledge Base Documents\n\n"
        for doc in documents:
            context += f"## {doc.get('title', 'Untitled')}\n"
            context += f"**Source:** {doc.get('source', 'Unknown')}\n"
            context += f"**Category:** {doc.get('category', 'General')}\n\n"
            context += f"{doc.get('content', '')}\n\n"
            context += "---\n\n"
        return context
    
    def _build_messages(self, user_query: str, context: str) -> List[Dict[str, str]]:
        """Build message list for OpenAI"""
        return [
            {
                "role": "system",
                "content": self.config.FINOPS_SYSTEM_PROMPT  # Will be imported from config
            },
            {
                "role": "user",
                "content": f"""Based on the following FinOps knowledge base:

{context}

Answer this question:

{user_query}

Provide:
1. Executive summary
2. Technical recommendation(s)
3. Estimated savings/impact (if applicable)
4. Implementation steps
5. Risk level (Low/Medium/High)
6. Next steps
7. Source(s)
"""
            }
        ]
    
    def answer(self, user_query: str, top_k: int = 5) -> Dict[str, Any]:
        """Generate answer using RAG pipeline"""
        logger.info(f"Processing query: {user_query}")
        
        # Retrieve relevant documents
        documents = self.retriever.retrieve(user_query, top_k=top_k)
        
        if not documents:
            logger.warning("No relevant documents found")
            return {
                "answer": "I couldn't find relevant information in the knowledge base to answer your question.",
                "sources": [],
                "documents": []
            }
        
        # Format context
        context = self._format_context(documents)
        
        # Build messages
        messages = self._build_messages(user_query, context)
        
        # Generate response
        try:
            response = self.openai_client.chat.completions.create(
                model=self.config.CHAT_DEPLOYMENT,
                messages=messages,
                temperature=0.7,
                max_tokens=2000,
                top_p=0.95
            )
            
            answer = response.choices[0].message.content
            sources = list(set([doc["source"] for doc in documents]))
            
            logger.info(f"✓ Generated response using {len(documents)} sources")
            
            return {
                "answer": answer,
                "sources": sources,
                "documents": documents,
                "usage": {
                    "prompt_tokens": response.usage.prompt_tokens,
                    "completion_tokens": response.usage.completion_tokens,
                    "total_tokens": response.usage.total_tokens
                }
            }
            
        except Exception as e:
            logger.error(f"Error generating response: {e}")
            return {
                "answer": f"Error generating response: {e}",
                "sources": [],
                "documents": documents
            }


if __name__ == "__main__":
    from config import AzureConfig
    
    config = AzureConfig()
    agent = FinOpsAgent(config)
    
    # Example queries
    test_queries = [
        "How can we optimize costs for our AKS clusters?",
        "What are the benefits of Reserved Instances vs Savings Plans?",
        "How should we implement proper tagging strategy?"
    ]
    
    for query in test_queries:
        result = agent.answer(query)
        print(f"\n{'='*60}")
        print(f"Query: {query}")
        print(f"{'='*60}")
        print(f"\nAnswer:\n{result['answer']}")
        print(f"\nSources: {', '.join(result['sources'])}")
        print(f"Tokens used: {result.get('usage', {}).get('total_tokens', 'N/A')}")
