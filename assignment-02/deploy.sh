#!/bin/bash
# =============================================================================
# Azure CLI Deployment Script
# Creates: Log Analytics + App Insights + Storage + Web App + Function App
#
# Prerequisites: Azure CLI installed  →  az login
# Usage: chmod +x deploy.sh && ./deploy.sh
# =============================================================================

set -euo pipefail

# ── Edit these values ─────────────────────────────────────────────────────────
PROJECT_NAME="dotnetdemo"
RESOURCE_GROUP="rg-${PROJECT_NAME}"
LOCATION="eastus"
TEMPLATE="./azuredeploy.json"
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "============================================================"
echo "  Azure Deployment: Web App + Function App + Log Analytics"
echo "============================================================"

# STEP 1 — Login
echo ""
echo "[1/5] Logging in to Azure..."
az login --output none
echo "      Logged in as: $(az account show --query user.name -o tsv)"
echo "      Subscription: $(az account show --query name -o tsv)"

# STEP 2 — Create Resource Group
echo ""
echo "[2/5] Creating resource group: ${RESOURCE_GROUP} in ${LOCATION}..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

# STEP 3 — Validate ARM Template
echo ""
echo "[3/5] Validating ARM template..."
az deployment group validate \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE" \
  --parameters projectName="$PROJECT_NAME" \
  --output none
echo "      Validation passed!"

# STEP 4 — Deploy ARM Template
echo ""
echo "[4/5] Deploying ARM template (takes ~2-3 mins)..."
DEPLOY_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE" \
  --parameters projectName="$PROJECT_NAME" \
  --query "properties.outputs" \
  --output json)

# STEP 5 — Show results
echo ""
echo "[5/5] Deployment complete! Resources created:"
echo ""

WEB_APP_NAME=$(echo "$DEPLOY_OUTPUT"   | grep -oP '"webAppName":\s*\{"[^"]*":\s*"\K[^"]+')
WEB_APP_URL=$(echo "$DEPLOY_OUTPUT"    | grep -oP '"webAppUrl":\s*\{"[^"]*":\s*"\K[^"]+')
FUNC_APP_NAME=$(echo "$DEPLOY_OUTPUT"  | grep -oP '"functionAppName":\s*\{"[^"]*":\s*"\K[^"]+')
FUNC_APP_URL=$(echo "$DEPLOY_OUTPUT"   | grep -oP '"functionAppUrl":\s*\{"[^"]*":\s*"\K[^"]+')
LOG_WS=$(echo "$DEPLOY_OUTPUT"         | grep -oP '"logAnalyticsWorkspaceName":\s*\{"[^"]*":\s*"\K[^"]+')

echo "  Web App Name    : $WEB_APP_NAME"
echo "  Web App URL     : $WEB_APP_URL"
echo ""
echo "  Function App    : $FUNC_APP_NAME"
echo "  Function URL    : $FUNC_APP_URL"
echo ""
echo "  Log Analytics   : $LOG_WS"
echo ""
echo "  Resource Group  : $RESOURCE_GROUP"
echo ""
echo "============================================================"
echo "  Save these values — you'll need them for CI/CD setup!"
echo "============================================================"
echo ""

# Save outputs to a file for CI/CD reference
cat > ./deploy-outputs.env << EOF
WEB_APP_NAME=${WEB_APP_NAME}
WEB_APP_URL=${WEB_APP_URL}
FUNC_APP_NAME=${FUNC_APP_NAME}
FUNC_APP_URL=${FUNC_APP_URL}
RESOURCE_GROUP=${RESOURCE_GROUP}
LOG_WORKSPACE=${LOG_WS}
EOF
echo "  Outputs saved to: ./deploy-outputs.env"
