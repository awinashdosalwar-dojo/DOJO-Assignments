#!/bin/bash
# =============================================================================
# Script: 01-create-app-registration.sh
# Purpose: Automate Azure App Registration setup for GitHub Actions OIDC auth
# Usage:   ./scripts/01-create-app-registration.sh
# =============================================================================

set -e  # Exit on any error

# ─── CONFIGURATION — Edit these values ───────────────────────────────────────
APP_NAME="github-actions-dojo"
GITHUB_ORG="awinashdosalwar-dojo"
GITHUB_REPO="DOJO-Assignments"
RESOURCE_GROUP="rg-dojo-demo"
LOCATION="eastus"
ROLE="Contributor"
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "============================================="
echo " Azure App Registration Setup for GitHub OIDC"
echo "============================================="
echo ""

# Step 0: Verify Azure CLI is logged in
echo "🔍 Checking Azure CLI login status..."
ACCOUNT=$(az account show --query "{name:name, tenantId:tenantId, subscriptionId:id}" -o json 2>/dev/null)

if [ $? -ne 0 ]; then
  echo "❌ Not logged in to Azure CLI. Please run: az login"
  exit 1
fi

SUBSCRIPTION_ID=$(echo $ACCOUNT | python3 -c "import sys,json; print(json.load(sys.stdin)['subscriptionId'])")
TENANT_ID=$(echo $ACCOUNT | python3 -c "import sys,json; print(json.load(sys.stdin)['tenantId'])")
ACCOUNT_NAME=$(echo $ACCOUNT | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")

echo "✅ Logged in as: $ACCOUNT_NAME"
echo "   Subscription: $SUBSCRIPTION_ID"
echo "   Tenant:       $TENANT_ID"
echo ""

# Confirm before proceeding
read -p "Continue with these values? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "Aborted."
  exit 0
fi

echo ""

# Step 1: Create App Registration
echo "📋 Step 1: Creating App Registration '$APP_NAME'..."

EXISTING=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null)

if [ -n "$EXISTING" ]; then
  echo "⚠️  App '$APP_NAME' already exists with ID: $EXISTING"
  APP_ID=$EXISTING
else
  APP_ID=$(az ad app create \
    --display-name "$APP_NAME" \
    --sign-in-audience AzureADMyOrg \
    --query appId -o tsv)
  echo "✅ App Registration created. Client ID: $APP_ID"
fi

echo ""

# Step 2: Create Service Principal
echo "📋 Step 2: Creating Service Principal..."

EXISTING_SP=$(az ad sp show --id $APP_ID --query id -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_SP" ]; then
  echo "⚠️  Service Principal already exists."
  SP_OBJECT_ID=$EXISTING_SP
else
  SP_OBJECT_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
  echo "✅ Service Principal created. Object ID: $SP_OBJECT_ID"
fi

echo ""

# Step 3: Create Federated Credentials
echo "📋 Step 3: Creating Federated Credentials..."

# For main branch
echo "   → Adding credential for 'main' branch..."
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-main-branch\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/main\",
    \"description\": \"GitHub Actions on main branch\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" > /dev/null 2>&1 || echo "   ⚠️  Credential 'github-main-branch' may already exist, skipping."

# For production environment
echo "   → Adding credential for 'production' environment..."
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-production-env\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:environment:production\",
    \"description\": \"GitHub Actions production environment\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" > /dev/null 2>&1 || echo "   ⚠️  Credential 'github-production-env' may already exist, skipping."

# For pull requests
echo "   → Adding credential for pull requests..."
az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-pull-requests\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:pull_request\",
    \"description\": \"GitHub Actions on pull requests\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" > /dev/null 2>&1 || echo "   ⚠️  Credential 'github-pull-requests' may already exist, skipping."

echo "✅ Federated credentials configured."
echo ""

# Step 4: Create Resource Group
echo "📋 Step 4: Creating Resource Group '$RESOURCE_GROUP'..."
az group create --name $RESOURCE_GROUP --location $LOCATION --output none
echo "✅ Resource group '$RESOURCE_GROUP' ready in $LOCATION."
echo ""

# Step 5: Assign Role
echo "📋 Step 5: Assigning '$ROLE' role on resource group..."
SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

EXISTING_ROLE=$(az role assignment list \
  --assignee $APP_ID \
  --scope $SCOPE \
  --query "[?roleDefinitionName=='$ROLE'].id" -o tsv 2>/dev/null)

if [ -n "$EXISTING_ROLE" ]; then
  echo "⚠️  Role assignment already exists, skipping."
else
  az role assignment create \
    --assignee $SP_OBJECT_ID \
    --role "$ROLE" \
    --scope $SCOPE \
    --output none
  echo "✅ '$ROLE' role assigned on $RESOURCE_GROUP."
fi

echo ""

# Step 6: Summary
echo "============================================="
echo " ✅ Setup Complete! Save these values:"
echo "============================================="
echo ""
echo "  AZURE_CLIENT_ID       = $APP_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo ""
echo "Add these as GitHub Secrets:"
echo ""
echo "  Repository level:"
echo "  gh secret set AZURE_CLIENT_ID --repo $GITHUB_ORG/$GITHUB_REPO --body \"$APP_ID\""
echo "  gh secret set AZURE_TENANT_ID --repo $GITHUB_ORG/$GITHUB_REPO --body \"$TENANT_ID\""
echo "  gh secret set AZURE_SUBSCRIPTION_ID --repo $GITHUB_ORG/$GITHUB_REPO --body \"$SUBSCRIPTION_ID\""
echo ""
echo "  Environment level (production):"
echo "  gh secret set AZURE_CLIENT_ID --repo $GITHUB_ORG/$GITHUB_REPO --env production --body \"$APP_ID\""
echo "  gh secret set AZURE_TENANT_ID --repo $GITHUB_ORG/$GITHUB_REPO --env production --body \"$TENANT_ID\""
echo "  gh secret set AZURE_SUBSCRIPTION_ID --repo $GITHUB_ORG/$GITHUB_REPO --env production --body \"$SUBSCRIPTION_ID\""
echo ""
echo "Next: Run the verification script:"
echo "  ./scripts/02-verify-setup.sh"
echo ""
