# Azure Web App + Function App — Complete Deployment Guide

## 📁 Project Structure

```
├── azuredeploy.json                      # ARM Template (all 7 resources)
├── deploy.sh                             # Azure CLI deployment script
├── .github/
│   └── workflows/
│       └── dotnet-deploy.yml             # GitHub Actions CI/CD pipeline
└── README.md                             # This file
```

---

## 🏗️ Resources Created by ARM Template

```
Resource Group
│
├── 📊 Log Analytics Workspace          ← Central log store for everything
├── 🔍 Application Insights             ← APM, traces, performance (linked to Log Analytics)
├── 💾 Storage Account                  ← Required by Function App runtime
│
├── 📋 App Service Plan (B1 Windows)    ← Hosts the Web App
├── 🌐 Azure Web App (.NET 8)           ← Your .NET application
│       └── Diagnostic Settings         ← Streams HTTP/App/Audit logs → Log Analytics
│
├── 📋 Consumption Plan (Y1 Dynamic)    ← Serverless plan for Function App
└── ⚡ Azure Function App (.NET 8)      ← Serverless functions
        └── Diagnostic Settings         ← Streams Function logs → Log Analytics
```

---

## 🚀 Step 1 — Deploy Infrastructure with Azure CLI

### Prerequisites
```bash
# Install Azure CLI (if not already installed)
# Windows:  winget install Microsoft.AzureCLI
# macOS:    brew install azure-cli
# Linux:    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

az --version    # verify installation
```

### Run the deployment
```bash
# Clone/download files, then:
chmod +x deploy.sh
./deploy.sh
```

### Or run commands manually (step by step):

```bash
# 1. Login to Azure
az login

# 2. Create Resource Group
az group create \
  --name rg-dotnetdemo \
  --location eastus

# 3. Validate ARM template (dry run — no charges)
az deployment group validate \
  --resource-group rg-dotnetdemo \
  --template-file azuredeploy.json \
  --parameters projectName="dotnetdemo"

# 4. Deploy ARM template
az deployment group create \
  --resource-group rg-dotnetdemo \
  --template-file azuredeploy.json \
  --parameters projectName="dotnetdemo" \
  --output table

# 5. View deployment outputs (URLs, names)
az deployment group show \
  --resource-group rg-dotnetdemo \
  --name azuredeploy \
  --query "properties.outputs" \
  --output table
```

> ⏱️ Deployment takes approximately **2–3 minutes**.

---

## 🔄 Step 2 — Deploy .NET App via GitHub Actions CI/CD

### How the pipeline works

```
Developer pushes to main
        │
        ▼
┌───────────────────────┐
│  JOB 1: Build & Test  │
│  ─────────────────    │
│  dotnet restore       │
│  dotnet build         │
│  dotnet test          │  ← Fails here? Deploy is blocked.
│  dotnet publish       │
│  Upload artifact      │
└──────────┬────────────┘
           │ (only if tests pass)
           ▼
┌───────────────────────┐
│  JOB 2: Deploy        │
│  ─────────────────    │
│  Download artifact    │
│  az login             │
│  webapps-deploy       │
│  Health check         │
└───────────────────────┘
```

### Setup GitHub Secrets

Go to: **GitHub Repo → Settings → Secrets and variables → Actions**

| Secret Name        | Value                                      | How to get it                     |
|--------------------|--------------------------------------------|------------------------------------|
| `AZURE_CREDENTIALS`  | Service Principal JSON                     | See command below                  |
| `AZURE_WEBAPP_NAME`  | Your web app name from ARM output          | From `deploy.sh` output            |

```bash
# Create Service Principal and get credentials JSON
az ad sp create-for-rbac \
  --name "sp-dotnetdemo-github" \
  --role "Contributor" \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-dotnetdemo \
  --sdk-auth

# Copy the FULL JSON output → paste as AZURE_CREDENTIALS secret
```

### Trigger a deployment
```bash
git add .
git commit -m "feat: initial dotnet app"
git push origin main
# GitHub Actions automatically triggers → builds → deploys → health checks
```

### Pull Request behavior
- PRs to `main` → **build + test only** (no deploy). Safe to review.
- Merged to `main` → **full deploy** automatically.

---

## 📊 Step 3 — Understanding Log Analytics Workspace

### What is Log Analytics?

Log Analytics Workspace is Azure's **central log aggregation and query engine**. Think of it as a database specifically designed to store, search, and analyze logs from all your Azure resources.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Log Analytics Workspace                       │
│                                                                  │
│   Receives logs from:              You can then:                 │
│   ┌─────────────────────┐          ┌──────────────────────────┐  │
│   │ ✅ Web App           │          │ 🔍 Query with KQL        │  │
│   │ ✅ Function App      │    ──▶   │ 📈 Create dashboards     │  │
│   │ ✅ App Insights      │          │ 🚨 Set up alerts         │  │
│   │ ✅ Storage Account   │          │ 📤 Export to SIEM        │  │
│   └─────────────────────┘          └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### What logs flow into Log Analytics from this deployment?

| Log Category             | Source         | What it tells you                              |
|--------------------------|----------------|------------------------------------------------|
| `AppServiceHTTPLogs`     | Web App        | Every HTTP request: URL, status code, latency  |
| `AppServiceAppLogs`      | Web App        | `Console.WriteLine`, `ILogger` output          |
| `AppServiceConsoleLogs`  | Web App        | stdout/stderr from the app process             |
| `AppServiceAuditLogs`    | Web App        | Who logged in via FTP/Kudu                     |
| `FunctionAppLogs`        | Function App   | Function execution start/end, errors, traces   |
| `AllMetrics`             | Both apps      | CPU %, memory, requests/sec, response times    |

### Useful KQL Queries to run in Log Analytics

Open **Azure Portal → Log Analytics Workspace → Logs**, then paste these:

```kusto
// ── See all HTTP requests to your Web App (last 1 hour) ──────────────────────
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, CsMethod, CsUriStem, ScStatus, TimeTaken
| order by TimeGenerated desc

// ── Count requests by HTTP status code ───────────────────────────────────────
AppServiceHTTPLogs
| where TimeGenerated > ago(24h)
| summarize RequestCount = count() by ScStatus
| render piechart

// ── Find all errors (5xx) ─────────────────────────────────────────────────────
AppServiceHTTPLogs
| where ScStatus >= 500
| where TimeGenerated > ago(24h)
| project TimeGenerated, CsUriStem, ScStatus, TimeTaken, CsUsername

// ── Application log output (ILogger / Console) ────────────────────────────────
AppServiceAppLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, Level, Message, ExceptionClass, ExceptionMessage
| order by TimeGenerated desc

// ── Slow requests (>2 seconds) ────────────────────────────────────────────────
AppServiceHTTPLogs
| where TimeTaken > 2000
| where TimeGenerated > ago(6h)
| project TimeGenerated, CsUriStem, TimeTaken, ScStatus
| order by TimeTaken desc

// ── Function App executions ───────────────────────────────────────────────────
FunctionAppLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, FunctionName, Level, Message
| order by TimeGenerated desc

// ── Average response time per hour ────────────────────────────────────────────
AppServiceHTTPLogs
| where TimeGenerated > ago(24h)
| summarize AvgResponseMs = avg(TimeTaken) by bin(TimeGenerated, 1h)
| render timechart
```

### Why Log Analytics matters

Without it, logs from each resource are siloed — you'd have to check each app separately with no history. With Log Analytics, everything flows into one place, and you get retention (30 days by default), cross-resource querying, alerting, and the ability to build dashboards that show your entire system health at a glance.

---

## 🧹 Cleanup

```bash
# Delete ALL resources (irreversible!)
az group delete --name rg-dotnetdemo --yes

# Or just delete individual resources
az webapp delete --name <webAppName> --resource-group rg-dotnetdemo
az functionapp delete --name <funcAppName> --resource-group rg-dotnetdemo
```

---

## 📌 Quick Reference

```bash
# View all resources in your group
az resource list --resource-group rg-dotnetdemo --output table

# Stream live Web App logs
az webapp log tail --name <webAppName> --resource-group rg-dotnetdemo

# Stream live Function App logs
az functionapp log tail --name <funcAppName> --resource-group rg-dotnetdemo

# Restart Web App
az webapp restart --name <webAppName> --resource-group rg-dotnetdemo

# Get Web App URL
az webapp show --name <webAppName> --resource-group rg-dotnetdemo \
  --query defaultHostName --output tsv
```
