# Step 4 — Add Secrets to GitHub

Store the Azure IDs as GitHub Secrets so workflows can reference them securely.

---

## What Values You Need

From Step 1 (App Registration Overview page):

```
AZURE_CLIENT_ID       = Application (client) ID
AZURE_TENANT_ID       = Directory (tenant) ID
AZURE_SUBSCRIPTION_ID = Your Azure Subscription ID
```

To find your Subscription ID:
```bash
az account show --query id -o tsv
```

---

## Where to Add Secrets

GitHub has three levels of secrets. Choose based on your use case:

| Level | Location | Use When |
|---|---|---|
| **Repository** | Settings → Secrets → Actions | Single repo, no environments |
| **Environment** | Settings → Environments → `production` → Secrets | Using `environment:` in workflows |
| **Organization** | Org Settings → Secrets | Multiple repos share same Azure app |

> ⚠️ If your workflow uses `environment: production`, secrets **must** be added to the **Environment**, not just the repo level.

---

## Option A: GitHub UI

### 4.1 — Add Repository-Level Secrets

1. Go to your GitHub repository
2. Click **"Settings"** tab
3. Click **"Secrets and variables"** → **"Actions"**
4. Click **"New repository secret"**

Add each secret:

| Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_TENANT_ID` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_SUBSCRIPTION_ID` | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |

---

### 4.2 — Add Environment-Level Secrets (for `environment: production`)

1. Go to **Settings → Environments**
2. Click **"New environment"** → name it `production`
3. Optionally add protection rules (required reviewers, branch restrictions)
4. Click **"Add secret"** and add the same three secrets

```
GitHub Repository
└── Settings
    ├── Secrets → Actions
    │   ├── AZURE_CLIENT_ID       ← repo-level (for branch workflows)
    │   ├── AZURE_TENANT_ID
    │   └── AZURE_SUBSCRIPTION_ID
    └── Environments
        └── production
            ├── AZURE_CLIENT_ID   ← env-level (for environment: production workflows)
            ├── AZURE_TENANT_ID
            └── AZURE_SUBSCRIPTION_ID
```

---

## Option B: GitHub CLI

```bash
# Install GitHub CLI if needed: https://cli.github.com

# Set your repo
REPO="awinashdosalwar-dojo/DOJO-Assignments"

# Add repository-level secrets
gh secret set AZURE_CLIENT_ID \
  --repo $REPO \
  --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

gh secret set AZURE_TENANT_ID \
  --repo $REPO \
  --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

gh secret set AZURE_SUBSCRIPTION_ID \
  --repo $REPO \
  --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Add environment-level secrets
gh secret set AZURE_CLIENT_ID \
  --repo $REPO \
  --env production \
  --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

gh secret set AZURE_TENANT_ID \
  --repo $REPO \
  --env production \
  --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

gh secret set AZURE_SUBSCRIPTION_ID \
  --repo $REPO \
  --env production \
  --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Verify secrets exist (values are hidden)
gh secret list --repo $REPO
gh secret list --repo $REPO --env production
```

---

## Verify Secrets in UI

After adding, your secrets page should look like this:

```
Repository secrets
✅ AZURE_CLIENT_ID          Updated just now
✅ AZURE_TENANT_ID          Updated just now
✅ AZURE_SUBSCRIPTION_ID    Updated just now

Environment secrets (production)
✅ AZURE_CLIENT_ID          Updated just now
✅ AZURE_TENANT_ID          Updated just now
✅ AZURE_SUBSCRIPTION_ID    Updated just now
```

---

## Security Best Practices

**Do:**
- ✅ Use environment secrets when using `environment:` in workflows
- ✅ Add environment protection rules (required reviewers for production)
- ✅ Use separate App Registrations for dev/staging/production
- ✅ Scope roles to the narrowest possible resource

**Don't:**
- ❌ Never commit secret values to your repo
- ❌ Never use `Owner` role — use `Contributor` or narrower
- ❌ Don't share the same App Registration across unrelated projects
- ❌ Never use client secrets/passwords — OIDC federated credentials are more secure

---

## Next Step

➡️ Continue to the workflows in `.github/workflows/`

Start with `01-validate-login.yml` to test your setup end-to-end.
