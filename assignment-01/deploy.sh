#!/bin/bash
# =============================================================================
# Azure CLI Deployment Script
# Deploys Azure Web App + Function App via ARM Template
#
# Prerequisites:
#   - Azure CLI installed (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
#   - Logged in: az login
#   - jq installed (for JSON parsing): sudo apt install jq
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
#   ./deploy.sh --env staging --location westus2
# =============================================================================

set -euo pipefail

# ── Color output helpers ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Default configuration (override via env vars or flags) ────────────────────
PROJECT_NAME="${PROJECT_NAME:-myproject}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-${PROJECT_NAME}-${ENVIRONMENT}}"
TEMPLATE_FILE="${TEMPLATE_FILE:-./azuredeploy.json}"
PARAMETERS_FILE="${PARAMETERS_FILE:-./azuredeploy.parameters.json}"
DEPLOYMENT_NAME="deploy-${PROJECT_NAME}-$(date +%Y%m%d%H%M%S)"
SQL_ADMIN_PASSWORD="${SQL_ADMIN_PASSWORD:-}"          # Set via env var — never hardcode

# ── Parse CLI flags ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)        ENVIRONMENT="$2";     shift 2 ;;
    --location)   LOCATION="$2";        shift 2 ;;
    --project)    PROJECT_NAME="$2";    shift 2 ;;
    --rg)         RESOURCE_GROUP="$2";  shift 2 ;;
    --help)
      echo "Usage: $0 [--env dev|staging|prod] [--location eastus] [--project myapp] [--rg my-rg]"
      exit 0 ;;
    *) error "Unknown flag: $1"; exit 1 ;;
  esac
done

# =============================================================================
# STEP 0 — Pre-flight checks
# =============================================================================
echo -e "\n${BOLD}═══════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Azure ARM Deployment — ${PROJECT_NAME} → ${ENVIRONMENT}${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}\n"

info "Running pre-flight checks..."

# Check Azure CLI is installed
if ! command -v az &>/dev/null; then
  error "Azure CLI not found. Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi

# Check logged in
ACCOUNT=$(az account show --query "{name:name, id:id}" -o json 2>/dev/null || true)
if [[ -z "$ACCOUNT" ]]; then
  warn "Not logged in to Azure. Running 'az login'..."
  az login
  ACCOUNT=$(az account show --query "{name:name, id:id}" -o json)
fi

SUBSCRIPTION_NAME=$(echo "$ACCOUNT" | jq -r '.name')
SUBSCRIPTION_ID=$(echo "$ACCOUNT" | jq -r '.id')
success "Logged in | Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"

# Validate template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  error "ARM template not found: $TEMPLATE_FILE"
  exit 1
fi

# Validate SQL password is set
if [[ -z "$SQL_ADMIN_PASSWORD" ]]; then
  warn "SQL_ADMIN_PASSWORD not set via env var."
  read -rsp "Enter SQL Admin Password: " SQL_ADMIN_PASSWORD
  echo
fi

# =============================================================================
# STEP 1 — Create or confirm Resource Group
# =============================================================================
echo
info "STEP 1 | Ensuring resource group exists: ${RESOURCE_GROUP}"

RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP")
if [[ "$RG_EXISTS" == "false" ]]; then
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags project="$PROJECT_NAME" environment="$ENVIRONMENT" managedBy="ARM-Template" \
    --output table
  success "Resource group created: ${RESOURCE_GROUP}"
else
  success "Resource group already exists: ${RESOURCE_GROUP}"
fi

# =============================================================================
# STEP 2 — Validate ARM template (dry run)
# =============================================================================
echo
info "STEP 2 | Validating ARM template (dry run)..."

az deployment group validate \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "@${PARAMETERS_FILE}" \
  --parameters \
    projectName="$PROJECT_NAME" \
    environment="$ENVIRONMENT" \
    location="$LOCATION" \
    sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
  --output table

success "Template validation passed."

# =============================================================================
# STEP 3 — What-if preview (shows changes before applying)
# =============================================================================
echo
info "STEP 3 | Running what-if preview (shows changes before applying)..."

az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "@${PARAMETERS_FILE}" \
  --parameters \
    projectName="$PROJECT_NAME" \
    environment="$ENVIRONMENT" \
    location="$LOCATION" \
    sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
  --result-format "FullResourcePayloads" \
  --output table || warn "What-if completed with warnings (non-fatal)."

echo
read -rp "$(echo -e "${YELLOW}Proceed with deployment? [y/N]: ${RESET}")" CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  warn "Deployment cancelled by user."
  exit 0
fi

# =============================================================================
# STEP 4 — Deploy ARM template
# =============================================================================
echo
info "STEP 4 | Deploying ARM template: ${DEPLOYMENT_NAME}"
START_TIME=$(date +%s)

DEPLOYMENT_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "@${PARAMETERS_FILE}" \
  --parameters \
    projectName="$PROJECT_NAME" \
    environment="$ENVIRONMENT" \
    location="$LOCATION" \
    sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
  --output json)

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

PROVISIONING_STATE=$(echo "$DEPLOYMENT_OUTPUT" | jq -r '.properties.provisioningState')

if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
  error "Deployment FAILED. State: ${PROVISIONING_STATE}"
  echo "$DEPLOYMENT_OUTPUT" | jq '.properties.error // empty'
  exit 1
fi

success "Deployment succeeded in ${ELAPSED}s."

# =============================================================================
# STEP 5 — Extract and display outputs
# =============================================================================
echo
info "STEP 5 | Deployment outputs:"

WEB_APP_NAME=$(echo "$DEPLOYMENT_OUTPUT"     | jq -r '.properties.outputs.webAppName.value')
WEB_APP_URL=$(echo "$DEPLOYMENT_OUTPUT"      | jq -r '.properties.outputs.webAppUrl.value')
FUNC_APP_NAME=$(echo "$DEPLOYMENT_OUTPUT"    | jq -r '.properties.outputs.functionAppName.value')
FUNC_APP_URL=$(echo "$DEPLOYMENT_OUTPUT"     | jq -r '.properties.outputs.functionAppUrl.value')
KEY_VAULT_NAME=$(echo "$DEPLOYMENT_OUTPUT"   | jq -r '.properties.outputs.keyVaultName.value')
SQL_FQDN=$(echo "$DEPLOYMENT_OUTPUT"         | jq -r '.properties.outputs.sqlServerFqdn.value')

echo -e "
${BOLD}┌─────────────────────────────────────────────────────────────┐${RESET}
${BOLD}│                  DEPLOYMENT SUMMARY                         │${RESET}
${BOLD}├─────────────────────────────────────────────────────────────┤${RESET}
  Resource Group : ${RESOURCE_GROUP}
  Subscription   : ${SUBSCRIPTION_NAME}
  Environment    : ${ENVIRONMENT}
  Duration       : ${ELAPSED}s

  🌐 Web App     : ${WEB_APP_NAME}
     URL         : ${WEB_APP_URL}

  ⚡ Function App: ${FUNC_APP_NAME}
     URL         : ${FUNC_APP_URL}

  🔑 Key Vault   : ${KEY_VAULT_NAME}
  🗄️  SQL Server  : ${SQL_FQDN}
${BOLD}└─────────────────────────────────────────────────────────────┘${RESET}
"

# =============================================================================
# STEP 6 — Post-deployment health checks
# =============================================================================
info "STEP 6 | Running post-deployment health checks..."

# Health check Web App
WEB_HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "${WEB_APP_URL}/health" || echo "000")
if [[ "$WEB_HTTP_STATUS" == "200" ]]; then
  success "Web App health check: HTTP ${WEB_HTTP_STATUS} ✓"
else
  warn "Web App health check returned HTTP ${WEB_HTTP_STATUS} (app may still be starting)"
fi

# Health check Function App
FUNC_HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "${FUNC_APP_URL}" || echo "000")
if [[ "$FUNC_HTTP_STATUS" == "200" ]]; then
  success "Function App health check: HTTP ${FUNC_HTTP_STATUS} ✓"
else
  warn "Function App health check returned HTTP ${FUNC_HTTP_STATUS} (app may still be starting)"
fi

# =============================================================================
# STEP 7 — Assign Managed Identity roles (Key Vault access)
# =============================================================================
info "STEP 7 | Assigning Key Vault roles to Managed Identities..."

WEB_APP_PRINCIPAL=$(az webapp identity show \
  --name "$WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)

FUNC_APP_PRINCIPAL=$(az functionapp identity show \
  --name "$FUNC_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)

KV_ID=$(az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)

az role assignment create \
  --assignee "$WEB_APP_PRINCIPAL" \
  --role "Key Vault Secrets User" \
  --scope "$KV_ID" \
  --output none && success "Web App → Key Vault Secrets User role assigned"

az role assignment create \
  --assignee "$FUNC_APP_PRINCIPAL" \
  --role "Key Vault Secrets User" \
  --scope "$KV_ID" \
  --output none && success "Function App → Key Vault Secrets User role assigned"

# =============================================================================
# DONE
# =============================================================================
echo
success "🎉 All steps completed successfully!"
info "View deployment in portal: https://portal.azure.com/#resource/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/overview"
