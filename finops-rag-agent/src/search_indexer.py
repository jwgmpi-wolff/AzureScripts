"""
Azure AI Search Indexing and Vector Embedding Pipeline
"""
import json
import logging
from typing import List, Dict, Any
from azure.search.documents import SearchClient
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import SearchIndex
from azure.core.credentials import AzureKeyCredential
from openai import AzureOpenAI
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SearchIndexManager:
    """Manage Azure AI Search index creation and document indexing"""
    
    def __init__(self, search_endpoint: str, api_key: str, api_version: str = "2024-07-01"):
        self.endpoint = search_endpoint
        self.api_key = api_key
        self.api_version = api_version
        self.credential = AzureKeyCredential(api_key)
        self.index_client = SearchIndexClient(endpoint=endpoint, credential=self.credential)
    
    def create_index(self, index_name: str, schema: Dict[str, Any]) -> bool:
        """Create a search index"""
        try:
            logger.info(f"Creating search index: {index_name}")
            
            # Convert schema dict to SearchIndex object
            index = SearchIndex(name=index_name, **schema)
            self.index_client.create_index(index)
            
            logger.info(f"✓ Index '{index_name}' created successfully")
            return True
        except Exception as e:
            logger.error(f"Error creating index: {e}")
            return False
    
    def delete_index(self, index_name: str) -> bool:
        """Delete a search index"""
        try:
            logger.info(f"Deleting index: {index_name}")
            self.index_client.delete_index(index_name)
            logger.info(f"✓ Index '{index_name}' deleted")
            return True
        except Exception as e:
            logger.error(f"Error deleting index: {e}")
            return False


class EmbeddingGenerator:
    """Generate embeddings using Azure OpenAI"""
    
    def __init__(self, openai_endpoint: str, api_key: str, 
                 embedding_model: str, api_version: str = "2024-02-15-preview"):
        self.client = AzureOpenAI(
            api_key=api_key,
            api_version=api_version,
            azure_endpoint=openai_endpoint
        )
        self.embedding_model = embedding_model
    
    def generate_embeddings(self, texts: List[str], batch_size: int = 10) -> List[List[float]]:
        """Generate embeddings for a list of texts"""
        embeddings = []
        
        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]
            try:
                response = self.client.embeddings.create(
                    input=batch,
                    model=self.embedding_model
                )
                
                for item in response.data:
                    embeddings.append(item.embedding)
                
                logger.info(f"✓ Generated embeddings for batch {i // batch_size + 1}")
                time.sleep(0.1)  # Rate limiting
                
            except Exception as e:
                logger.error(f"Error generating embeddings: {e}")
                embeddings.extend([None] * len(batch))
        
        return embeddings


class DocumentIndexer:
    """Index documents with embeddings into Azure AI Search"""
    
    def __init__(self, search_endpoint: str, api_key: str, 
                 openai_endpoint: str, openai_key: str,
                 embedding_model: str, index_name: str):
        self.search_client = SearchClient(
            endpoint=search_endpoint,
            index_name=index_name,
            credential=AzureKeyCredential(api_key)
        )
        self.embedding_gen = EmbeddingGenerator(
            openai_endpoint=openai_endpoint,
            api_key=openai_key,
            embedding_model=embedding_model
        )
        self.index_name = index_name
    
    def index_documents(self, chunks: List[Dict[str, str]], batch_size: int = 10) -> int:
        """Index documents with embeddings"""
        total_indexed = 0
        
        # Generate embeddings for all chunks
        logger.info(f"Generating embeddings for {len(chunks)} chunks...")
        texts = [chunk["content"] for chunk in chunks]
        embeddings = self.embedding_gen.generate_embeddings(texts, batch_size=batch_size)
        
        # Index documents in batches
        for i in range(0, len(chunks), batch_size):
            batch_chunks = chunks[i:i + batch_size]
            batch_embeddings = embeddings[i:i + batch_size]
            
            documents = []
            for chunk, embedding in zip(batch_chunks, batch_embeddings):
                if embedding is not None:
                    doc = {
                        "id": chunk["id"],
                        "content": chunk["content"],
                        "contentVector": embedding,
                        "source": chunk["source"],
                        "category": chunk["category"],
                        "title": chunk["title"],
                        "metadata": chunk.get("metadata", "")
                    }
                    documents.append(doc)
            
            try:
                result = self.search_client.upload_documents(documents=documents)
                total_indexed += len(result)
                logger.info(f"✓ Indexed batch {i // batch_size + 1}: {len(result)} documents")
            except Exception as e:
                logger.error(f"Error indexing batch: {e}")
        
        logger.info(f"✓ Total documents indexed: {total_indexed}")
        return total_indexed


def load_chunks_from_jsonl(jsonl_file: str) -> List[Dict[str, str]]:
    """Load chunks from JSONL file"""
    chunks = []
    with open(jsonl_file, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                chunks.append(json.loads(line))
    return chunks


if __name__ == "__main__":
    from config import AzureConfig
    
    config = AzureConfig()
    
    # Load chunks
    chunks = load_chunks_from_jsonl("chunks.jsonl")
    logger.info(f"Loaded {len(chunks)} chunks from chunks.jsonl")
    
    # Index documents
    indexer = DocumentIndexer(
        search_endpoint=config.SEARCH_ENDPOINT,
        api_key=config.SEARCH_API_KEY,
        openai_endpoint=config.OPENAI_ENDPOINT,
        openai_key=config.OPENAI_API_KEY,
        embedding_model=config.EMBEDDING_DEPLOYMENT,
        index_name=config.SEARCH_INDEX_NAME
    )
    
    total = indexer.index_documents(chunks)
    logger.info(f"Indexing complete: {total} documents indexed")
