"""
app/routers/ai_search.py

Endpoints that combine Azure AI Search (semantic retrieval) with
Azure AI Foundry / GPT-4o (grounded natural-language answers).

Both clients authenticate using the pod's workload identity — no API keys.
"""
from __future__ import annotations

from typing import Annotated

from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery
from fastapi import APIRouter, Depends, HTTPException, status
from openai import AzureOpenAI
from pydantic import BaseModel, Field

from app.config import Settings
from app.dependencies import (
    get_openai_client,
    get_search_client,
    get_settings,
    require_api_key,
)

router = APIRouter()


# --------------------------------------------------------------------------- #
# Request / Response models                                                    #
# --------------------------------------------------------------------------- #
class SearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=500, description="Natural-language search query")
    top: int = Field(5, ge=1, le=20, description="Number of results to return")


class SearchResult(BaseModel):
    id: str
    name: str
    version: str
    description: str | None
    score: float


class SearchResponse(BaseModel):
    results: list[SearchResult]
    query: str


class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=1000, description="Question about packages")
    top_k: int = Field(5, ge=1, le=10, description="Number of context documents to retrieve")


class ChatResponse(BaseModel):
    answer: str
    sources: list[str]
    model: str


# --------------------------------------------------------------------------- #
# Routes                                                                       #
# --------------------------------------------------------------------------- #
@router.post(
    "/packages",
    response_model=SearchResponse,
    summary="Semantic search over the package index",
)
def search_packages(
    body: SearchRequest,
    search_client: Annotated[SearchClient, Depends(get_search_client)],
    openai_client: Annotated[AzureOpenAI, Depends(get_openai_client)],
    settings: Annotated[Settings, Depends(get_settings)],
    _: str = Depends(require_api_key),
):
    """Embed the query with text-embedding-3-small, then run a vector search
    against the AI Search index and return the top-k results."""
    try:
        embedding_response = openai_client.embeddings.create(
            model="text-embedding-3-small",
            input=body.query,
        )
        query_vector = embedding_response.data[0].embedding
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"errors": [{"code": "EMBEDDING_FAILED", "message": str(exc)}]},
        )

    vector_query = VectorizedQuery(
        vector=query_vector,
        k_nearest_neighbors=body.top,
        fields="content_vector",
    )

    try:
        results = search_client.search(
            search_text=body.query,          # Hybrid: keyword + vector
            vector_queries=[vector_query],
            select=["id", "name", "version", "description"],
            top=body.top,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"errors": [{"code": "SEARCH_FAILED", "message": str(exc)}]},
        )

    items = [
        SearchResult(
            id=r["id"],
            name=r.get("name", ""),
            version=r.get("version", ""),
            description=r.get("description"),
            score=r.get("@search.score", 0.0),
        )
        for r in results
    ]
    return SearchResponse(results=items, query=body.query)


@router.post(
    "/chat",
    response_model=ChatResponse,
    summary="Ask a natural-language question answered from the package index (RAG)",
)
def chat_with_packages(
    body: ChatRequest,
    search_client: Annotated[SearchClient, Depends(get_search_client)],
    openai_client: Annotated[AzureOpenAI, Depends(get_openai_client)],
    settings: Annotated[Settings, Depends(get_settings)],
    _: str = Depends(require_api_key),
):
    """Retrieve relevant package documents then ask GPT-4o to answer the
    question grounded in those documents. Returns the answer and source IDs."""

    # 1. Embed the question
    try:
        embedding = openai_client.embeddings.create(
            model="text-embedding-3-small",
            input=body.question,
        ).data[0].embedding
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc))

    # 2. Retrieve context from AI Search
    vector_query = VectorizedQuery(
        vector=embedding, k_nearest_neighbors=body.top_k, fields="content_vector"
    )
    try:
        raw = list(
            search_client.search(
                search_text=body.question,
                vector_queries=[vector_query],
                select=["id", "name", "version", "description"],
                top=body.top_k,
            )
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc))

    source_ids = [r["id"] for r in raw]
    context_parts = [
        f"Package: {r.get('name')} v{r.get('version')}\n{r.get('description', '')}"
        for r in raw
    ]
    context = "\n\n---\n\n".join(context_parts)

    # 3. Ask GPT-4o with the retrieved context
    system_prompt = (
        "You are a helpful assistant for a software package registry. "
        "Answer the user's question using ONLY the context provided. "
        "If the answer is not in the context, say you don't know. "
        "Be concise and accurate."
    )
    user_prompt = f"Context:\n{context}\n\nQuestion: {body.question}"

    try:
        completion = openai_client.chat.completions.create(
            model=settings.openai_deployment,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": user_prompt},
            ],
            temperature=0.2,
            max_tokens=800,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc))

    return ChatResponse(
        answer=completion.choices[0].message.content or "",
        sources=source_ids,
        model=completion.model,
    )
