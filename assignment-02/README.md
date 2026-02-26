# Azure Managed Identity + Key Vault + Function App

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Resource Group                         │
│                                                                     │
│   ┌─────────────────┐    System-Assigned     ┌──────────────────┐  │
│   │  Function App   │◄── Managed Identity ──►│   Key Vault      │  │
│   │  (Python 3.11)  │    (auto token, no pw) │                  │  │
│   │                 │                         │  Secret:         │  │
│   │  GET /GetSecret │    RBAC Role:           │  MyAppSecret ✓   │  │
│   └────────┬────────┘    Key Vault            └──────────────────┘  │
│            │             Secrets User                                │
│            │                                                         │
│   ┌────────▼────────┐   ┌──────────────────┐  ┌────────────────┐   │
│   │  Consumption    │   │  Storage Account │  │  App Insights  │   │
│   │  Plan (Y1)      │   │  (func runtime)  │  │  + Log Analytics│  │
│   └─────────────────┘   └──────────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

**Key principle:** The Function App has **zero stored credentials**.
It authenticates to Key Vault using its Managed Identity — Azure automatically
issues and rotates the token behind the scenes.

---

## Resources Created (9 total)

| # | Resource | Purpose |
|---|----------|---------|
| 1 | Log Analytics Workspace | Central log store |
| 2 | Application Insights | APM and tracing |
| 3 | Storage Account | Function App runtime backing |
| 4 | Key Vault | Secure secret store |
| 5 | Key Vault Secret | Demo secret `MyAppSecret` |
| 6 | Consumption Plan (Y1) | Serverless hosting |
| 7 | Function App | Python app with **SystemAssigned identity** |
| 8 | **RBAC Role Assignment** | Grants identity → `Key Vault Secrets User` |
| 9 | Diagnostic Settings | Streams logs → Log Analytics |

---

## Step 1 — Deploy Infrastructure

```bash
chmod +x deploy.sh
./deploy.sh
```

Or run manually:

```bash
# Login
az login

# Create resource group
az group create --name rg-kvdemo --location eastus

# Validate (no charges, dry run)
az deployment group validate \
  --resource-group rg-kvdemo \
  --template-file azuredeploy.json \
  --parameters projectName="kvdemo"

# Deploy (~3 minutes)
az deployment group create \
  --resource-group rg-kvdemo \
  --template-file azuredeploy.json \
  --parameters projectName="kvdemo" \
  --output table
```

---

## Step 2 — Deploy the Function App Code

```bash
cd function-app

# Install Azure Functions Core Tools (if not installed)
# https://docs.microsoft.com/azure/azure-functions/functions-run-local

# Deploy to Azure
func azure functionapp publish <FUNC_APP_NAME>
```

Or via Azure CLI:

```bash
# Zip and deploy
zip -r functionapp.zip . --exclude "*.pyc" --exclude "__pycache__/*"

az functionapp deployment source config-zip \
  --resource-group rg-kvdemo \
  --name <FUNC_APP_NAME> \
  --src functionapp.zip
```

---

## Step 3 — Test It

```bash
# Call the function
curl https://<FUNC_APP_NAME>.azurewebsites.net/api/GetSecret

# Expected response:
{
  "secret": "Hello-from-KeyVault-via-ManagedIdentity!",
  "secretName": "MyAppSecret",
  "vaultUrl": "https://kvdemo-kv-xxxxxx.vault.azure.net/",
  "message": "Secret retrieved via Managed Identity — no passwords used!"
}
```

---

## How Managed Identity Works (step by step)

```
1. ARM template deploys Function App with:
      "identity": { "type": "SystemAssigned" }
   → Azure creates a service principal in Azure AD automatically

2. ARM template creates RBAC role assignment:
      Principal  : Function App's Managed Identity
      Role       : Key Vault Secrets User (built-in)
      Scope      : the Key Vault resource

3. At runtime, Python code does:
      credential = ManagedIdentityCredential()
      client = SecretClient(vault_url=..., credential=credential)

4. ManagedIdentityCredential calls the local IMDS endpoint:
      http://169.254.169.254/metadata/identity/oauth2/token
   → Azure returns a short-lived OAuth2 token for the identity
   → No password, no certificate, no secret string — ever

5. SecretClient uses the token to call Key Vault REST API
   → Key Vault checks: does this identity have Secrets User role? ✅
   → Returns the secret value

6. Function returns the secret to the HTTP caller
```

---

## Useful Azure CLI Commands

```bash
# View all resources
az resource list --resource-group rg-kvdemo --output table

# Check Managed Identity of Function App
az functionapp identity show \
  --name <FUNC_APP_NAME> \
  --resource-group rg-kvdemo

# List Key Vault secrets
az keyvault secret list \
  --vault-name <KV_NAME> \
  --output table

# Add a new secret to Key Vault
az keyvault secret set \
  --vault-name <KV_NAME> \
  --name "AnotherSecret" \
  --value "my-new-secret-value"

# Check RBAC assignments on Key Vault
az role assignment list \
  --scope $(az keyvault show --name <KV_NAME> --resource-group rg-kvdemo --query id -o tsv) \
  --output table

# Stream live Function App logs
az functionapp log tail \
  --name <FUNC_APP_NAME> \
  --resource-group rg-kvdemo

# Query logs in Log Analytics (last 1 hour)
az monitor log-analytics query \
  --workspace <LOG_WORKSPACE_NAME> \
  --analytics-query "FunctionAppLogs | where TimeGenerated > ago(1h) | project TimeGenerated, Level, Message | order by TimeGenerated desc" \
  --output table
```

---

## Why Managed Identity vs. Other Approaches

| Approach | Credentials stored? | Auto-rotated? | Recommended? |
|----------|--------------------|--------------:|:------------:|
| **Managed Identity** | ❌ None | ✅ Yes | ✅ **Yes** |
| Connection string in app settings | ✅ Yes (plaintext) | ❌ No | ❌ |
| Secret in Key Vault + SP credentials | ✅ Yes (SP secret) | ❌ No | ⚠️ Partial |
| Hardcoded in code | ✅ Yes (dangerous!) | ❌ No | ❌ Never |

---

## Cleanup

```bash
# Delete everything (irreversible)
az group delete --name rg-kvdemo --yes --no-wait
```
