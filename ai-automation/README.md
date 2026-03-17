# AI Automation

Python scripts demonstrating practical AI integrations using Azure OpenAI, Azure AI Search,
Azure Document Intelligence, and custom agentic workflows.

## Projects

| Directory | Description |
|-----------|-------------|
| `openai-chat` | Chat completion client with system prompt and exponential-backoff retry |
| `rag-pipeline` | Retrieval-Augmented Generation: embed → search → generate |
| `document-intelligence` | Extract key-value pairs from PDF invoices via Form Recognizer |
| `agentic-workflow` | Tool-calling agent loop that iterates until a task is complete |

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install openai azure-search-documents azure-ai-formrecognizer python-dotenv
```

Create a `.env` file with:
```
AZURE_OPENAI_ENDPOINT=https://<your-resource>.openai.azure.com/
AZURE_OPENAI_API_KEY=<key>
AZURE_OPENAI_DEPLOYMENT=gpt-4o
AZURE_SEARCH_ENDPOINT=https://<your-search>.search.windows.net
AZURE_SEARCH_KEY=<key>
AZURE_SEARCH_INDEX=documents
FORM_RECOGNIZER_ENDPOINT=https://<your-fr>.cognitiveservices.azure.com/
FORM_RECOGNIZER_KEY=<key>
```
