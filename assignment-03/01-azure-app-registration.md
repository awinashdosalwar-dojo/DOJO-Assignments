# Step 1 — Create an Azure App Registration

An **App Registration** is an identity in Azure AD that GitHub Actions will authenticate as.

---

## Option A: Azure Portal (UI)

### 1.1 — Open Azure Active Directory

1. Go to [https://portal.azure.com](https://portal.azure.com)
2. Search for **"Azure Active Directory"** in the top search bar
3. Click **"App registrations"** in the left sidebar
4. Click **"+ New registration"**

---

### 1.2 — Fill in the Registration Form

| Field | Value |
|---|---|
| **Name** | `github-actions-<your-repo-name>` (e.g. `github-actions-dojo`) |
| **Supported account types** | `Accounts in this organizational directory only (Single tenant)` |
| **Redirect URI** | Leave blank |

Click **"Register"**.

---

### 1.3 — Save These Values

After registration, you are taken to the **Overview** page. Copy and save:

```
Application (client) ID:  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  ← AZURE_CLIENT_ID
Directory (tenant) ID:    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  ← AZURE_TENANT_ID
```

> ⚠️ Do NOT copy the "Object ID" — you need the **Application (client) ID**.

---

## Option B: Azure CLI

```bash
# 1. Login (ensure you are in the correct tenant)
az login --tenant <YOUR_TENANT_ID>

# 2. Create the App Registration
az ad app create \
  --display-name "github-actions-dojo" \
  --sign-in-audience AzureADMyOrg

# 3. Capture the App ID
APP_ID=$(az ad app list \
  --display-name "github-actions-dojo" \
  --query "[0].appId" -o tsv)

echo "Client ID: $APP_ID"

# 4. Create a Service Principal for the app
az ad sp create --id $APP_ID

echo "App Registration created successfully."
echo "Save this Client ID: $APP_ID"
```

---

## What Was Created

```
Azure Active Directory
└── App Registrations
    └── github-actions-dojo
        ├── Application (client) ID  ← used as AZURE_CLIENT_ID
        ├── Directory (tenant) ID    ← used as AZURE_TENANT_ID
        ├── Certificates & secrets   ← (we'll add federated credential next)
        └── API permissions          ← (we'll configure these next)
```

---

## Next Step

➡️ Continue to [`02-federated-credentials.md`](./02-federated-credentials.md)
