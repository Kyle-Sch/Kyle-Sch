"""
agentic-workflow/agent_runner.py

A simple ReAct-style (Reason + Act) agentic loop built on the
OpenAI function-calling API.

The agent is given a task and a set of tools. It iterates:
  1. Think — call the LLM; receive either a tool call or a final answer.
  2. Act   — if a tool call was requested, execute it and feed the result back.
  3. Repeat until the LLM returns a plain-text final answer (no tool call).

Available tools:
  - web_search(query)      — simulated keyword search, returns snippets
  - summarize(text)        — calls GPT to condense a block of text
  - get_current_date()     — returns today's ISO date

Prerequisites:
    pip install openai python-dotenv
"""

from __future__ import annotations

import json
import logging
import os
from datetime import date
from typing import Any

from dotenv import load_dotenv
from openai import AzureOpenAI
from openai.types.chat import ChatCompletionMessageToolCall

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

client = AzureOpenAI(
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    api_key=os.environ["AZURE_OPENAI_API_KEY"],
    api_version="2024-02-01",
)
DEPLOYMENT = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o")

MAX_ITERATIONS = 10  # Safety cap to prevent infinite loops


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------
def web_search(query: str) -> str:
    """
    Simulated web search. In production, replace with a real search API
    (e.g. Bing Search, Azure AI Search, SerpAPI).
    """
    logger.info("[tool] web_search(%r)", query)
    # Stub — returns plausible-looking results for demo purposes
    return json.dumps([
        {
            "title": f"Result 1 for '{query}'",
            "snippet": f"This is a relevant excerpt about {query}. It covers the main concepts and provides useful context for the topic.",
            "url": "https://docs.example.com/topic1",
        },
        {
            "title": f"Result 2 for '{query}'",
            "snippet": f"Another perspective on {query}, including practical examples and best-practice recommendations.",
            "url": "https://blog.example.com/topic2",
        },
    ])


def summarize(text: str) -> str:
    """Use GPT to produce a one-paragraph summary of *text*."""
    logger.info("[tool] summarize(text[:%d]…)", min(len(text), 80))
    response = client.chat.completions.create(
        model=DEPLOYMENT,
        messages=[
            {"role": "system", "content": "Summarize the following text in one concise paragraph."},
            {"role": "user", "content": text},
        ],
        temperature=0.2,
        max_tokens=256,
    )
    return response.choices[0].message.content or ""


def get_current_date() -> str:
    """Return today's date in ISO 8601 format."""
    logger.info("[tool] get_current_date()")
    return date.today().isoformat()


# Registry: maps tool name → callable
TOOL_REGISTRY: dict[str, Any] = {
    "web_search": web_search,
    "summarize": summarize,
    "get_current_date": get_current_date,
}

# OpenAI tool schema definitions
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": "Search the web for current information on a topic. Returns a list of result snippets.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "The search query string."}
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "summarize",
            "description": "Summarize a long piece of text into a concise paragraph.",
            "parameters": {
                "type": "object",
                "properties": {
                    "text": {"type": "string", "description": "The text to summarize."}
                },
                "required": ["text"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_current_date",
            "description": "Returns today's date in ISO 8601 format (YYYY-MM-DD).",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]

SYSTEM_PROMPT = (
    "You are a research assistant. When given a task, break it down and use the "
    "available tools to gather information. Once you have enough information, "
    "provide a comprehensive final answer WITHOUT calling any more tools."
)


# ---------------------------------------------------------------------------
# Agent loop
# ---------------------------------------------------------------------------
def run_agent(task: str) -> str:
    """
    Run the agentic loop for *task*.

    Returns the final answer string when the model stops calling tools.
    """
    messages: list[dict] = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": task},
    ]

    for iteration in range(1, MAX_ITERATIONS + 1):
        logger.info("--- Iteration %d ---", iteration)

        response = client.chat.completions.create(
            model=DEPLOYMENT,
            messages=messages,
            tools=TOOLS,
            tool_choice="auto",
            temperature=0.3,
            max_tokens=1024,
        )

        message = response.choices[0].message
        finish_reason = response.choices[0].finish_reason

        # Append the assistant message (may include tool_calls)
        messages.append(message.model_dump(exclude_unset=True))

        # If no tool call was requested, we have our final answer
        if finish_reason == "stop" or not message.tool_calls:
            logger.info("Agent finished after %d iteration(s).", iteration)
            return message.content or ""

        # Execute each requested tool call and feed results back
        for tool_call in message.tool_calls:
            result = _execute_tool(tool_call)
            messages.append({
                "role": "tool",
                "tool_call_id": tool_call.id,
                "content": result,
            })

    logger.warning("Reached MAX_ITERATIONS (%d) without a final answer.", MAX_ITERATIONS)
    return "Agent did not converge within the iteration limit."


def _execute_tool(tool_call: ChatCompletionMessageToolCall) -> str:
    """Dispatch a tool call to the appropriate function and return the result."""
    name = tool_call.function.name
    try:
        args = json.loads(tool_call.function.arguments or "{}")
    except json.JSONDecodeError:
        return json.dumps({"error": "Invalid JSON arguments from model."})

    func = TOOL_REGISTRY.get(name)
    if func is None:
        logger.error("Unknown tool requested: %s", name)
        return json.dumps({"error": f"Tool '{name}' is not available."})

    try:
        return str(func(**args))
    except Exception as exc:
        logger.exception("Tool '%s' raised an exception.", name)
        return json.dumps({"error": str(exc)})


# ---------------------------------------------------------------------------
# Demo
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    task = (
        "Research the current best practices for securing AKS clusters. "
        "Provide a concise summary of the top recommendations."
    )
    print(f"Task: {task}\n")
    answer = run_agent(task)
    print(f"Final Answer:\n{answer}")
