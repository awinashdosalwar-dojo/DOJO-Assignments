# Step 2 — Configure Federated Credentials (OIDC)

A **Federated Credential** tells Azure AD:
> "Trust GitHub Actions tokens from THIS specific repo/branch/environment."

This replaces client secrets entirely — no secret rotation needed.

---

## Understanding the Subject Claim

GitHub generates a unique `subject` claim based on what triggered the workflow:

| Trigger | Subject Claim Format |
|---|---|
| Branch push | `repo:ORG/REPO:ref:refs/heads/BRANCH` |
| Pull Request | `repo:ORG/REPO:pull_request` |
| Environment | `repo:ORG/REPO:environment:ENV_NAME` |
| Tag | `repo:ORG/REPO:ref:refs/tags/TAG` |

> The subject claim must **exactly match** what's configured in Azure — otherwise login fails.

---

## Option A: Azure Portal (UI)

### 2.1 — Navigate to Federated Credentials

1. In **Azure AD → App Registrations**, open your app (`github-actions-dojo`)
2. Click **"Certificates & secrets"** in the left sidebar
3. Click the **"Federated credentials"** tab
4. Click **"+ Add credential"**

---

### 2.2 — Configure for a Branch (e.g. `main`)

| Field | Value |
|---|---|
| **Federated credential scenario** | `GitHub Actions deploying Azure resources` |
| **Organization** | `awinashdosalwar-dojo` |
| **Repository** | `DOJO-Assignments` |
| **Entity type** | `Branch` |
| **GitHub branch name** | `main` |
| **Name** | `github-main-branch` |
| **Description** | `Allow GitHub Actions on main branch` |

Click **"Add"**.

---

### 2.3 — Configure for an Environment (e.g. `production`)

Repeat the steps above with:

| Field | Value |
|---|---|
| **Entity type** | `Environment` |
| **GitHub environment name** | `production` |
| **Name** | `github-production-env` |

> You need **one federated credential per entity** (branch, environment, PR, etc.).

---

### 2.4 — Configure for Pull Requests

| Field | Value |
|---|---|
| **Entity type** | `Pull request` |
| **Name** | `github-pull-requests` |

---

## Option B: Azure CLI

```bash
# Replace these values
APP_ID="<YOUR_APP_CLIENT_ID>"
ORG="awinashdosalwar-dojo"
REPO="DOJO-Assignments"

# Federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$ORG"'/'"$REPO"':ref:refs/heads/main",
    "description": "GitHub Actions on main branch",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Federated credential for production environment
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-production-env",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$ORG"'/'"$REPO"':environment:production",
    "description": "GitHub Actions production environment",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$ORG"'/'"$REPO"':pull_request",
    "description": "GitHub Actions on pull requests",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Verify credentials were created
az ad app federated-credential list --id $APP_ID -o table
```

---

## Verify Setup

After creating credentials, verify the subject claim matches your workflow.

Your workflow trigger determines the subject:

```yaml
# This workflow uses environment: production
# Subject claim will be: repo:ORG/REPO:environment:production
jobs:
  deploy:
    environment: production   # ← this drives the subject claim
```

```yaml
# This workflow has no environment
# Subject claim will be: repo:ORG/REPO:ref:refs/heads/main
on:
  push:
    branches: [main]
```

---

## Common Mistake

```
# ❌ WRONG - subject mismatch
Workflow uses:   environment: production
Azure has:       repo:ORG/REPO:ref:refs/heads/main

# ✅ CORRECT - subject matches
Workflow uses:   environment: production  
Azure has:       repo:ORG/REPO:environment:production
```

---

## Next Step

➡️ Continue to [`03-role-assignments.md`](./03-role-assignments.md)
