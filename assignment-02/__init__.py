"""
Azure Function: GetSecret
-------------------------
Reads a secret from Azure Key Vault using the Function App's
System-Assigned Managed Identity — NO passwords or API keys required.

Flow:
  HTTP Request
      │
      ▼
  Function App (Managed Identity token auto-fetched by SDK)
      │
      ▼
  Azure Key Vault (RBAC: Key Vault Secrets User)
      │
      ▼
  Secret value returned to caller
"""

import os
import logging
import json
import azure.functions as func
from azure.identity import ManagedIdentityCredential
from azure.keyvault.secrets import SecretClient


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("GetSecret function triggered.")

    # ── Read config from environment variables (set by ARM template) ──────────
    key_vault_url = os.environ.get("KEY_VAULT_URL")
    secret_name   = os.environ.get("SECRET_NAME", "MyAppSecret")

    if not key_vault_url:
        logging.error("KEY_VAULT_URL environment variable is not set.")
        return func.HttpResponse(
            json.dumps({"error": "KEY_VAULT_URL not configured."}),
            status_code=500,
            mimetype="application/json"
        )

    try:
        # ── Authenticate using Managed Identity (NO secrets needed) ──────────
        # ManagedIdentityCredential automatically uses the Function App's
        # System-Assigned identity. No client ID, secret, or certificate needed.
        credential = ManagedIdentityCredential()

        # ── Create Key Vault client ───────────────────────────────────────────
        client = SecretClient(vault_url=key_vault_url, credential=credential)

        # ── Retrieve the secret ───────────────────────────────────────────────
        secret = client.get_secret(secret_name)

        logging.info(f"Successfully retrieved secret '{secret_name}' from Key Vault.")

        return func.HttpResponse(
            json.dumps({
                "secret":      secret.value,
                "secretName":  secret.name,
                "vaultUrl":    key_vault_url,
                "message":     "Secret retrieved via Managed Identity — no passwords used!"
            }),
            status_code=200,
            mimetype="application/json"
        )

    except Exception as e:
        logging.error(f"Failed to retrieve secret from Key Vault: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            mimetype="application/json"
        )
