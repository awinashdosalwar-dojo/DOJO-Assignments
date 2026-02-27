# Step 3 — Assign Azure Permissions (Role Assignments)

The App Registration now has an identity, but no permissions to do anything in Azure.
We grant permissions via **Azure RBAC Role Assignments**.

---

## Choosing the Right Role

Always use the **least privileged role** needed:

| Role | What it can do | When to use |
|---|---|---|
| `Reader` | Read resources only | Read-only workflows, audits |
| `Contributor` | Create/update/delete resources | Most deployment workflows |
| `Owner` | Full control including RBAC | Rarely — avoid if possible |
| `Storage Blob Data Contributor` | Read/write blob storage | Storage-specific workflows |
| `AcrPush` | Push images to Container Registry | Docker build/push workflows |
| `Website Contributor` | Manage App Service only | Web app deployments |

---

## Scoping the Role Assignment

Assign the role at the **narrowest scope** possible:

```
Management Group  (broadest — avoid)
    └── Subscription
            └── Resource Group  (recommended for most cases)
                    └── Individual Resource  (narrowest — most secure)
```

---

## Option A: Azure Portal (UI)

### 3.1 — Assign at Resource Group Level (Recommended)

1. Go to **Azure Portal → Resource Groups**
2. Open the target resource group (or create one)
3. Click **"Access control (IAM)"** in the left sidebar
4. Click **"+ Add"** → **"Add role assignment"**
5. In **Role** tab: search for and select `Contributor`
6. Click **"Next"**
7. In **Members** tab:
   - Select **"User, group, or service principal"**
   - Click **"+ Select members"**
   - Search for `github-actions-dojo`
   - Select it and click **"Select"**
8. Click **"Review + assign"** twice

---

### 3.2 — Assign at Subscription Level (Broader Access)

1. Go to **Azure Portal → Subscriptions**
2. Open your subscription
3. Click **"Access control (IAM)"**
4. Follow the same steps as above

---

## Option B: Azure CLI

```bash
# Set your values
APP_ID="<YOUR_APP_CLIENT_ID>"
SUBSCRIPTION_ID="<YOUR_SUBSCRIPTION_ID>"
RESOURCE_GROUP="rg-dojo-demo"    # change to your resource group

# Get the Service Principal Object ID (needed for role assignment)
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)

echo "Service Principal Object ID: $SP_OBJECT_ID"

# --- Option 1: Contributor on a specific Resource Group (recommended) ---
# First create the resource group if it doesn't exist
az group create --name $RESOURCE_GROUP --location eastus

# Assign Contributor role on the Resource Group
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

echo "✅ Contributor role assigned on resource group: $RESOURCE_GROUP"

# --- Option 2: Contributor on the entire Subscription ---
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

echo "✅ Contributor role assigned on subscription: $SUBSCRIPTION_ID"

# --- Option 3: Reader-only (for read-only workflows) ---
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Verify role assignments
az role assignment list \
  --assignee $SP_OBJECT_ID \
  --output table
```

---

## Verify Permissions

```bash
# List all role assignments for the service principal
az role assignment list \
  --assignee $APP_ID \
  --all \
  --output table

# Expected output:
# Principal          Role         Scope
# -----------------  -----------  ------------------------------------------
# github-actions...  Contributor  /subscriptions/xxx/resourceGroups/rg-dojo
```

---

## API Permissions (Optional — for Microsoft Graph access)

If your workflow needs to interact with **Azure AD itself** (create users, read groups, etc.), you also need API permissions:

### In Azure Portal:
1. App Registration → **"API permissions"**
2. Click **"+ Add a permission"**
3. Choose **"Microsoft Graph"** → **"Application permissions"**
4. Add needed permissions (e.g. `Directory.Read.All`)
5. Click **"Grant admin consent"** (requires Global Admin)

### Via CLI:
```bash
# Add Microsoft Graph permission (e.g. read directory)
GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"  # Microsoft Graph

az ad app permission add \
  --id $APP_ID \
  --api $GRAPH_APP_ID \
  --api-permissions 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role  # Directory.Read.All

# Grant admin consent
az ad app permission admin-consent --id $APP_ID
```

> For most GitHub Actions deployment workflows, API permissions are NOT needed.

---

## Summary of What's Been Created

```
Azure AD
└── App Registration: github-actions-dojo
    ├── Application (client) ID  ✅
    ├── Federated Credentials    ✅
    │   ├── github-main-branch
    │   ├── github-production-env
    │   └── github-pull-requests
    └── Service Principal
        └── Role Assignments     ✅
            └── Contributor → rg-dojo-demo
```

---

## Next Step

➡️ Continue to [`04-github-secrets.md`](./04-github-secrets.md)
