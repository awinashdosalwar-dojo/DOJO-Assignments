# Azure OIDC Authentication with GitHub Actions

Authenticate GitHub Actions to Azure using **OpenID Connect (OIDC)** — no long-lived secrets required.

---

## Project Structure

```
azure-oidc-project/
├── README.md                        ← You are here
├── docs/
│   ├── 01-azure-app-registration.md ← Step 1: Create App Registration
│   ├── 02-federated-credentials.md  ← Step 2: Configure Federated Identity
│   ├── 03-role-assignments.md       ← Step 3: Assign Azure Permissions
│   ├── 04-github-secrets.md         ← Step 4: Add Secrets to GitHub
│   └── 05-troubleshooting.md        ← Step 5: Common Errors & Fixes
├── scripts/
│   ├── 01-create-app-registration.sh   ← Automate Steps 1–3
│   └── 02-verify-setup.sh              ← Verify everything is configured
└── .github/
    └── workflows/
        ├── 01-validate-login.yml        ← Workflow A: Test Azure login only
        ├── 02-deploy-resource-group.yml ← Workflow B: Create a Resource Group
        └── 03-full-deploy.yml           ← Workflow C: Full deploy with environment
```

---

## How OIDC Works (No Secrets!)

```
GitHub Actions Runner
       │
       │  1. Request OIDC token from GitHub
       ▼
GitHub Token Service
       │
       │  2. Issue signed JWT with repo/branch/env claims
       ▼
Azure AD (via azure/login@v2)
       │
       │  3. Validate JWT against registered Federated Credential
       │  4. Issue short-lived Azure access token
       ▼
Azure Resources (ARM, CLI, etc.)
```

---

## Quick Start

Follow the docs in order:

| Step | Doc | What it does |
|------|-----|--------------|
| 1 | `docs/01-azure-app-registration.md` | Create the App Registration in Azure AD |
| 2 | `docs/02-federated-credentials.md` | Link GitHub repo to Azure via OIDC |
| 3 | `docs/03-role-assignments.md` | Grant Azure permissions to the app |
| 4 | `docs/04-github-secrets.md` | Store IDs in GitHub Secrets |
| 5 | Run a workflow | Test authentication end-to-end |

Or run the automated script (requires Azure CLI + appropriate permissions):

```bash
chmod +x scripts/01-create-app-registration.sh
./scripts/01-create-app-registration.sh
```

---

## Prerequisites

- Azure CLI installed (`az --version`)
- Access to an Azure subscription
- Admin or **Application Administrator** role in Azure AD
- A GitHub repository
