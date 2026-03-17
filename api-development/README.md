# API Development

REST API implementation with FastAPI and Azure API Management policy examples.

## Structure

```
api-development/
├── fastapi-rest/
│   ├── main.py          # FastAPI application (CRUD for packages resource)
│   ├── models.py        # Pydantic request/response models
│   └── requirements.txt
└── apim-policies/
    ├── rate-limit-policy.xml      # Inbound: rate limit + JWT validation + CORS
    └── transform-response.xml    # Outbound: strip/rename response fields
```

## Running Locally

```bash
cd fastapi-rest
pip install -r requirements.txt
uvicorn main:app --reload
# Docs at http://localhost:8000/docs
```

## APIM Policies

Policies are applied at the API or operation level in Azure API Management.
Import them via the Azure portal or `az apim api policy` CLI commands.
