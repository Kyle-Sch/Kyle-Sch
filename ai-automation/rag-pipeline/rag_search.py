"""
rag-pipeline/rag_search.py

Retrieval-Augmented Generation (RAG) pipeline:
  1. Embed the user query with Azure OpenAI text-embedding-3-large
  2. Perform a vector search against an Azure AI Search index
  3. Build a context string from the top-k results
  4. Pass context + query to GPT-4o to generate a grounded answer

Prerequisites:
  pip install openai azure-search-documents python-dotenv
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass

from azure.core.credentials import AzureKeyCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from dotenv import load_dotenv
from openai import AzureOpenAI

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Clients
# ---------------------------------------------------------------------------
openai_client = AzureOpenAI(
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    api_key=os.environ["AZURE_OPENAI_API_KEY"],
    api_version="2024-02-01",
)

search_client = SearchClient(
    endpoint=os.environ["AZURE_SEARCH_ENDPOINT"],
    index_name=os.environ["AZURE_SEARCH_INDEX"],
    credential=AzureKeyCredential(os.environ["AZURE_SEARCH_KEY"]),
)

EMBEDDING_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-3-large")
CHAT_DEPLOYMENT = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o")
VECTOR_FIELD = "content_vector"   # Field name in the search index holding embeddings
CONTENT_FIELD = "content"         # Field holding the source text
TITLE_FIELD = "title"             # Field holding document title / source reference


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------
@dataclass
class SearchResult:
    title: str
    content: str
    score: float


# ---------------------------------------------------------------------------
# Step 1: Embed the query
# ---------------------------------------------------------------------------
def embed_query(query: str) -> list[float]:
    """Return a vector embedding for *query* using Azure OpenAI."""
    logger.info("Embedding query (%d chars)…", len(query))
    response = openai_client.embeddings.create(
        model=EMBEDDING_DEPLOYMENT,
        input=query,
    )
    return response.data[0].embedding


# ---------------------------------------------------------------------------
# Step 2: Vector search
# ---------------------------------------------------------------------------
def vector_search(query_vector: list[float], top_k: int = 5) -> list[SearchResult]:
    """Search the Azure AI Search index using the query embedding."""
    logger.info("Searching index '%s' (top_k=%d)…", os.environ["AZURE_SEARCH_INDEX"], top_k)

    vector_query = VectorizedQuery(
        vector=query_vector,
        k_nearest_neighbors=top_k,
        fields=VECTOR_FIELD,
    )

    results = search_client.search(
        search_text=None,        # Pure vector search; set to query for hybrid
        vector_queries=[vector_query],
        select=[TITLE_FIELD, CONTENT_FIELD],
        top=top_k,
    )

    documents: list[SearchResult] = []
    for r in results:
        documents.append(
            SearchResult(
                title=r.get(TITLE_FIELD, "Unknown"),
                content=r.get(CONTENT_FIELD, ""),
                score=r["@search.score"],
            )
        )
        logger.debug("  [%.4f] %s", r["@search.score"], r.get(TITLE_FIELD))

    return documents


# ---------------------------------------------------------------------------
# Step 3: Build context and generate answer
# ---------------------------------------------------------------------------
def build_context(results: list[SearchResult]) -> str:
    """Format retrieved documents into a context block for the LLM."""
    sections = []
    for i, doc in enumerate(results, start=1):
        sections.append(f"[{i}] {doc.title}\n{doc.content.strip()}")
    return "\n\n---\n\n".join(sections)


def generate_answer(query: str, context: str) -> str:
    """Call GPT-4o with the retrieved context to produce a grounded answer."""
    system_prompt = (
        "You are a helpful assistant. Answer the user's question using ONLY the "
        "information provided in the context below. "
        "If the answer is not contained in the context, say 'I don't have enough "
        "information to answer that.' "
        "Cite the source number in brackets (e.g. [1]) when you use information from it."
    )

    user_message = f"Context:\n{context}\n\nQuestion: {query}"

    response = openai_client.chat.completions.create(
        model=CHAT_DEPLOYMENT,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        temperature=0.1,
        max_tokens=1024,
    )
    return response.choices[0].message.content or ""


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
def rag_query(query: str, top_k: int = 5) -> dict:
    """
    Full RAG pipeline.

    Returns:
        {
            "query": str,
            "answer": str,
            "sources": [{"title": str, "score": float}, ...]
        }
    """
    embedding = embed_query(query)
    results = vector_search(embedding, top_k=top_k)
    context = build_context(results)
    answer = generate_answer(query, context)

    return {
        "query": query,
        "answer": answer,
        "sources": [{"title": r.title, "score": r.score} for r in results],
    }


# ---------------------------------------------------------------------------
# Demo
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import json

    sample_query = "What are the network requirements for deploying AKS with Azure CNI?"
    result = rag_query(sample_query, top_k=5)

    print(f"\nQuery: {result['query']}\n")
    print(f"Answer:\n{result['answer']}\n")
    print("Sources:")
    for src in result["sources"]:
        print(f"  [{src['score']:.4f}] {src['title']}")
