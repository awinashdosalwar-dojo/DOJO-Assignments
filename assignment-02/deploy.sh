#!/bin/bash
# =============================================================================
# Azure CLI Deployment Script
# Managed Identity + Key Vault + Function App
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
# =============================================================================

set -euo pipefail

# ── Configuration — edit these ────────────────────────────────────────────────
PROJECT_NAME="kvdemo"
RESOURCE_GROUP="rg-${PROJECT_NAME}"
LOCATION="eastus"
TEMPLATE="./azuredeploy.json"
SECRET_NAME="MyAppSecret"
SECRET_VALUE="Hello-from-KeyVault-via-ManagedIdentity!"
# ─────────────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

echo ""
echo "============================================================"
echo "  Azure: Managed Identity + Key Vault + Function App"
echo "============================================================"

# STEP 1 — Login
echo ""
info "STEP 1 | Login to Azure"
az login --output none
success "Logged in as: $(az account show --query user.name -o tsv)"
success "Subscription: $(az account show --query name -o tsv)"

# STEP 2 — Resource Group
echo ""
info "STEP 2 | Create resource group: ${RESOURCE_GROUP}"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

# STEP 3 — Validate
echo ""
info "STEP 3 | Validate ARM template (dry run)"
az deployment group validate \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE" \
  --parameters \
      projectName="$PROJECT_NAME" \
      keyVaultSecretName="$SECRET_NAME" \
      keyVaultSecretValue="$SECRET_VALUE" \
  --output none
success "Template validation passed"

# STEP 4 — Deploy
echo ""
info "STEP 4 | Deploy ARM template (~3 minutes)..."
DEPLOY=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE" \
  --parameters \
      projectName="$PROJECT_NAME" \
      keyVaultSecretName="$SECRET_NAME" \
      keyVaultSecretValue="$SECRET_VALUE" \
  --output json)

# Parse outputs
FUNC_NAME=$(echo "$DEPLOY"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['functionAppName']['value'])")
FUNC_URL=$(echo "$DEPLOY"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['functionAppUrl']['value'])")
KV_NAME=$(echo "$DEPLOY"     | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['keyVaultName']['value'])")
KV_URI=$(echo "$DEPLOY"      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['keyVaultUri']['value'])")
PRINCIPAL=$(echo "$DEPLOY"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['managedIdentityPrincipalId']['value'])")
LOG_WS=$(echo "$DEPLOY"      | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['properties']['outputs']['logAnalyticsWorkspaceName']['value'])")

echo ""
echo "============================================================"
echo "  DEPLOYMENT COMPLETE"
echo "============================================================"
echo ""
echo "  Function App  : $FUNC_NAME"
echo "  Function URL  : $FUNC_URL"
echo ""
echo "  Key Vault     : $KV_NAME"
echo "  Key Vault URI : $KV_URI"
echo ""
echo "  Identity ID   : $PRINCIPAL"
echo "  Log Analytics : $LOG_WS"
echo ""
echo "============================================================"

# STEP 5 — Verify RBAC assignment
echo ""
info "STEP 5 | Verifying RBAC role assignment on Key Vault..."
ROLE_CHECK=$(az role assignment list \
  --assignee "$PRINCIPAL" \
  --scope "$(az keyvault show --name "$KV_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)" \
  --query "[0].roleDefinitionName" \
  --output tsv)

if [[ "$ROLE_CHECK" == "Key Vault Secrets User" ]]; then
  success "RBAC confirmed: Function App identity has 'Key Vault Secrets User' on $KV_NAME"
else
  warn "RBAC role not yet visible (can take 1-2 mins to propagate). Verify in portal."
fi

# STEP 6 — Quick test hint
echo ""
info "STEP 6 | Test your function once deployed:"
echo ""
echo "  curl https://${FUNC_NAME}.azurewebsites.net/api/GetSecret"
echo ""
echo "  Expected response:"
echo "  { \"secret\": \"Hello-from-KeyVault-via-ManagedIdentity!\" }"
echo ""

# Save outputs
cat > ./deploy-outputs.env << EOF
FUNC_APP_NAME=${FUNC_NAME}
FUNC_APP_URL=${FUNC_URL}
KEY_VAULT_NAME=${KV_NAME}
KEY_VAULT_URI=${KV_URI}
MANAGED_IDENTITY_PRINCIPAL=${PRINCIPAL}
RESOURCE_GROUP=${RESOURCE_GROUP}
LOG_WORKSPACE=${LOG_WS}
EOF
success "Outputs saved → ./deploy-outputs.env"
