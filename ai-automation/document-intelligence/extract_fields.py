"""
document-intelligence/extract_fields.py

Extracts structured key-value pairs from a PDF invoice using
Azure Document Intelligence (formerly Form Recognizer).

The "prebuilt-invoice" model understands standard invoice fields
(vendor, dates, line items, totals, etc.) without any training data.

Prerequisites:
    pip install azure-ai-formrecognizer python-dotenv

Usage:
    python extract_fields.py invoice.pdf
    python extract_fields.py https://example.com/invoice.pdf
"""

from __future__ import annotations

import json
import logging
import os
import sys
from pathlib import Path
from typing import Any

from azure.ai.formrecognizer import DocumentAnalysisClient
from azure.core.credentials import AzureKeyCredential
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------
client = DocumentAnalysisClient(
    endpoint=os.environ["FORM_RECOGNIZER_ENDPOINT"],
    credential=AzureKeyCredential(os.environ["FORM_RECOGNIZER_KEY"]),
)

# Fields we care about from the prebuilt-invoice model
INVOICE_FIELDS = [
    "VendorName",
    "VendorAddress",
    "CustomerName",
    "CustomerAddress",
    "InvoiceId",
    "InvoiceDate",
    "DueDate",
    "SubTotal",
    "TotalTax",
    "InvoiceTotal",
    "PurchaseOrder",
    "BillingAddress",
    "ShippingAddress",
]


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------
def _field_value(field: Any) -> str | None:
    """Safely extract a string representation of a document field value."""
    if field is None:
        return None
    vt = field.value_type
    if vt == "string":
        return field.value
    if vt in ("date", "time"):
        return str(field.value)
    if vt == "currency":
        v = field.value
        return f"{v.symbol or ''}{v.amount:.2f}" if v else None
    if vt == "address":
        v = field.value
        parts = filter(None, [v.house_number, v.road, v.city, v.state, v.postal_code, v.country_region])
        return ", ".join(parts)
    # Fallback: use the raw content string from the document
    return field.content


def extract_line_items(invoice_fields: dict) -> list[dict]:
    """Extract the Items table from an invoice result."""
    items_field = invoice_fields.get("Items")
    if items_field is None or items_field.value is None:
        return []

    line_items = []
    for item in items_field.value:
        row = {}
        item_fields = item.value or {}
        for key in ("Description", "Quantity", "UnitPrice", "Amount", "ProductCode"):
            row[key] = _field_value(item_fields.get(key))
        line_items.append(row)
    return line_items


# ---------------------------------------------------------------------------
# Main extraction function
# ---------------------------------------------------------------------------
def extract_invoice(source: str) -> dict:
    """
    Analyse an invoice PDF and return structured data.

    Args:
        source: Local file path OR public URL to the PDF.

    Returns:
        Dictionary of extracted invoice fields and line items.
    """
    logger.info("Submitting document for analysis: %s", source)

    if source.startswith("http://") or source.startswith("https://"):
        poller = client.begin_analyze_document_from_url("prebuilt-invoice", source)
    else:
        path = Path(source)
        if not path.exists():
            raise FileNotFoundError(f"File not found: {source}")
        with path.open("rb") as f:
            poller = client.begin_analyze_document("prebuilt-invoice", f)

    result = poller.result()
    logger.info("Analysis complete. Pages analysed: %d", len(result.pages))

    if not result.documents:
        logger.warning("No invoice documents detected in the file.")
        return {}

    # Use the first recognised invoice document
    invoice = result.documents[0]
    fields = invoice.fields or {}

    extracted: dict[str, Any] = {
        "confidence": invoice.confidence,
        "fields": {},
        "line_items": [],
    }

    for field_name in INVOICE_FIELDS:
        field = fields.get(field_name)
        extracted["fields"][field_name] = {
            "value": _field_value(field),
            "confidence": field.confidence if field else None,
        }

    extracted["line_items"] = extract_line_items(fields)
    return extracted


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python extract_fields.py <path-or-url-to-invoice.pdf>")
        sys.exit(1)

    source_arg = sys.argv[1]
    data = extract_invoice(source_arg)

    print(json.dumps(data, indent=2, default=str))
