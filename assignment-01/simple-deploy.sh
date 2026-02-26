#!/bin/bash
# =============================================================================
# Simple Azure CLI Deployment Script
# Deploys: Azure Web App + Azure Function App via ARM Template
#
# Prerequisites:
#   1. Install Azure CLI  →  https://docs.microsoft.com/cli/azure/install-azure-cli
#   2. Run: az login
#
# Usage:
#   chmod +x simple-deploy.sh
#   ./simple-deploy.sh
# =============================================================================

# ── Configuration — edit these values ────────────────────────────────────────
PROJECT_NAME="myapp"
RESOURCE_GROUP="rg-${PROJECT_NAME}"
LOCATION="eastus"
TEMPLATE="./simple-azuredeploy.json"

# ─────────────────────────────────────────────────────────────────────────────

echo "======================================================"
echo "  Azure Deployment: Web App + Function App"
echo "======================================================"

# STEP 1 — Login to Azure
echo ""
echo "STEP 1 | Logging in to Azure..."
az login

# STEP 2 — Create Resource Group
echo ""
echo "STEP 2 | Creating resource group: ${RESOURCE_GROUP}..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# STEP 3 — Validate the ARM Template
echo ""
echo "STEP 3 | Validating ARM template..."
az deployment group validate \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE" \
  --parameters projectName="$PROJECT_NAME"

echo "Validation passed!"

# STEP 4 — Deploy the ARM Template
echo ""
echo "STEP 4 | Deploying resources (this takes ~2-3 minutes)..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE" \
  --parameters projectName="$PROJECT_NAME" \
  --output table

# STEP 5 — Show deployment outputs
echo ""
echo "STEP 5 | Deployment complete! Your resources:"
az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$(az deployment group list --resource-group "$RESOURCE_GROUP" --query '[0].name' -o tsv)" \
  --query "properties.outputs" \
  --output table

echo ""
echo "======================================================"
echo "  Done! Both apps are live on Azure."
echo "======================================================"
