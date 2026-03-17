"""
openai-chat/chat_client.py

Thin wrapper around the Azure OpenAI chat completions API.
Features:
  - Configurable system prompt
  - Multi-turn conversation history
  - Exponential backoff retry on transient errors (rate limit / 5xx)
  - Streaming support (optional)

Usage:
    python chat_client.py
"""

from __future__ import annotations

import logging
import os
import time
from typing import Iterator

from dotenv import load_dotenv
from openai import AzureOpenAI, RateLimitError, APIStatusError

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Client setup
# ---------------------------------------------------------------------------
client = AzureOpenAI(
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    api_key=os.environ["AZURE_OPENAI_API_KEY"],
    api_version="2024-02-01",
)

DEPLOYMENT = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o")

DEFAULT_SYSTEM_PROMPT = (
    "You are a knowledgeable DevOps and cloud infrastructure assistant. "
    "Answer questions concisely and accurately. "
    "When providing code or CLI commands, use code blocks."
)


# ---------------------------------------------------------------------------
# Retry decorator with exponential backoff
# ---------------------------------------------------------------------------
def with_retry(
    func,
    *,
    max_attempts: int = 5,
    base_delay: float = 1.0,
    max_delay: float = 60.0,
    retryable_exceptions: tuple = (RateLimitError, APIStatusError),
):
    """Call *func* with exponential backoff on transient errors."""
    for attempt in range(1, max_attempts + 1):
        try:
            return func()
        except retryable_exceptions as exc:
            # APIStatusError wraps 5xx; only retry those, not 4xx client errors
            if isinstance(exc, APIStatusError) and exc.status_code < 500:
                raise
            if attempt == max_attempts:
                logger.error("Max retries reached. Raising last exception.")
                raise
            delay = min(base_delay * (2 ** (attempt - 1)), max_delay)
            logger.warning(
                "Attempt %d/%d failed (%s). Retrying in %.1fs…",
                attempt,
                max_attempts,
                type(exc).__name__,
                delay,
            )
            time.sleep(delay)


# ---------------------------------------------------------------------------
# Chat client
# ---------------------------------------------------------------------------
class ChatClient:
    """Stateful chat client that maintains conversation history."""

    def __init__(
        self,
        system_prompt: str = DEFAULT_SYSTEM_PROMPT,
        deployment: str = DEPLOYMENT,
        max_tokens: int = 1024,
        temperature: float = 0.2,
    ) -> None:
        self.deployment = deployment
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.history: list[dict] = [{"role": "system", "content": system_prompt}]

    def send(self, user_message: str) -> str:
        """Send a user message, return the assistant's reply, update history."""
        self.history.append({"role": "user", "content": user_message})

        def _call():
            return client.chat.completions.create(
                model=self.deployment,
                messages=self.history,
                max_tokens=self.max_tokens,
                temperature=self.temperature,
            )

        response = with_retry(_call)
        reply = response.choices[0].message.content or ""
        self.history.append({"role": "assistant", "content": reply})
        logger.info(
            "Tokens used — prompt: %d, completion: %d",
            response.usage.prompt_tokens,
            response.usage.completion_tokens,
        )
        return reply

    def send_streaming(self, user_message: str) -> Iterator[str]:
        """Send a message and yield content chunks as they stream in."""
        self.history.append({"role": "user", "content": user_message})
        full_reply: list[str] = []

        with client.chat.completions.stream(
            model=self.deployment,
            messages=self.history,
            max_tokens=self.max_tokens,
            temperature=self.temperature,
        ) as stream:
            for chunk in stream:
                delta = chunk.choices[0].delta.content if chunk.choices else None
                if delta:
                    full_reply.append(delta)
                    yield delta

        self.history.append({"role": "assistant", "content": "".join(full_reply)})

    def reset(self) -> None:
        """Clear conversation history (keeps system prompt)."""
        system = self.history[0]
        self.history = [system]


# ---------------------------------------------------------------------------
# Demo
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    chat = ChatClient()

    questions = [
        "What is the difference between a Deployment and a StatefulSet in Kubernetes?",
        "How would I roll back the last deployment?",
    ]

    for q in questions:
        print(f"\nUser: {q}")
        answer = chat.send(q)
        print(f"Assistant: {answer}")
