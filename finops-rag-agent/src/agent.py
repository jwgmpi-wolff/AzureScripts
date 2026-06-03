#!/usr/bin/env python3
"""
FinOps RAG Agent - Main Entry Point
Azure AI Foundry Hosted Agent for FinOps recommendations
"""
import json
import logging
import os
from typing import Any

from src.rag_agent import FinOpsAgent
from src.azure_apis import FinOpsAzureAPIs
from config import AzureConfig

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class FinOpsAgentHandler:
    """Handle incoming requests to the FinOps agent"""
    
    def __init__(self):
        self.config = AzureConfig()
        self.agent = FinOpsAgent(self.config)
        self.azure_apis = FinOpsAzureAPIs(self.config.SUBSCRIPTION_ID)
    
    def handle_message(self, message: str, context: dict = None) -> dict:
        """Handle incoming user message"""
        logger.info(f"Processing message: {message}")
        
        try:
            # Check if message is asking for specific data
            if self._is_data_request(message):
                return self._handle_data_request(message, context)
            else:
                # Default to RAG-based answer
                result = self.agent.answer(message)
                return {
                    "status": "success",
                    "response": result["answer"],
                    "sources": result.get("sources", []),
                    "usage": result.get("usage", {})
                }
        
        except Exception as e:
            logger.error(f"Error handling message: {e}")
            return {
                "status": "error",
                "response": f"Error processing request: {str(e)}"
            }
    
    def _is_data_request(self, message: str) -> bool:
        """Determine if message is asking for live Azure data"""
        data_keywords = [
            "current cost", "daily cost", "forecast", "spending",
            "advisor", "recommendation", "vm", "disk", "public ip",
            "tagging", "compliance", "inventory", "alert"
        ]
        return any(keyword in message.lower() for keyword in data_keywords)
    
    def _handle_data_request(self, message: str, context: dict = None) -> dict:
        """Handle requests for live Azure data"""
        logger.info("Handling data request...")
        
        try:
            insights = self.azure_apis.get_finops_insights()
            
            # Combine live data with RAG answer
            context_str = json.dumps(insights, indent=2, default=str)
            
            # Enhance prompt with live data
            enhanced_query = f"""
User Question: {message}

Current Azure Insights:
{context_str}

Based on the above live data and FinOps best practices, provide a comprehensive answer.
"""
            
            result = self.agent.answer(enhanced_query)
            
            return {
                "status": "success",
                "response": result["answer"],
                "live_data": insights,
                "sources": result.get("sources", []),
                "usage": result.get("usage", {})
            }
        
        except Exception as e:
            logger.error(f"Error handling data request: {e}")
            return {
                "status": "error",
                "response": f"Error retrieving live data: {str(e)}"
            }


# For Azure AI Foundry / Prompt Flow integration
async def handle_request(request_body: dict) -> dict:
    """Entry point for Azure AI Foundry"""
    try:
        handler = FinOpsAgentHandler()
        message = request_body.get("message") or request_body.get("query")
        context = request_body.get("context", {})
        
        response = handler.handle_message(message, context)
        return response
    
    except Exception as e:
        logger.error(f"Error in handle_request: {e}")
        return {
            "status": "error",
            "response": f"Internal error: {str(e)}"
        }


if __name__ == "__main__":
    # Test the agent locally
    handler = FinOpsAgentHandler()
    
    test_queries = [
        "How can we optimize AKS costs?",
        "What's our current spending trend?",
        "Show me cost recommendations from Advisor",
        "Check for unattached disks in our subscription",
        "What are the tagging best practices?"
    ]
    
    print("\n" + "="*70)
    print("FinOps RAG Agent - Test")
    print("="*70)
    
    for query in test_queries:
        print(f"\n📝 Query: {query}")
        print("-" * 70)
        
        response = handler.handle_message(query)
        
        print(f"Status: {response['status']}")
        if response['status'] == 'success':
            print(f"\n{response['response']}")
            if response.get('sources'):
                print(f"\n📚 Sources: {', '.join(response['sources'])}")
        else:
            print(f"Error: {response['response']}")
        
        print()
