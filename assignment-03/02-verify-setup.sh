#!/bin/bash
# =============================================================================
# Script: 02-verify-setup.sh
# Purpose: Verify the Azure App Registration is correctly configured
# Usage:   ./scripts/02-verify-setup.sh
# =============================================================================

set -e

# ─── CONFIGURATION — Edit these values ───────────────────────────────────────
APP_NAME="github-actions-dojo"
GITHUB_ORG="awinashdosalwar-dojo"
GITHUB_REPO="DOJO-Assignments"
RESOURCE_GROUP="rg-dojo-demo"
# ─────────────────────────────────────────────────────────────────────────────

PASS=0
FAIL=0

check() {
  local label=$1
  local result=$2
  if [ -n "$result" ] && [ "$result" != "null" ] && [ "$result" != "[]" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — NOT FOUND"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "============================================="
echo " Azure OIDC Setup Verification"
echo "============================================="
echo ""

# Get App ID
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null)
TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)
SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)

echo "🔍 Checking App Registration..."
check "App Registration '$APP_NAME' exists" "$APP_ID"

if [ -z "$APP_ID" ]; then
  echo ""
  echo "❌ App Registration not found. Run script 01 first."
  exit 1
fi

echo ""
echo "🔍 Checking Federated Credentials..."
CREDS=$(az ad app federated-credential list --id $APP_ID -o json 2>/dev/null)

MAIN_CRED=$(echo $CREDS | python3 -c "import sys,json; creds=json.load(sys.stdin); print(next((c['name'] for c in creds if 'refs/heads/main' in c.get('subject','')), ''))" 2>/dev/null)
ENV_CRED=$(echo $CREDS | python3 -c "import sys,json; creds=json.load(sys.stdin); print(next((c['name'] for c in creds if 'environment:production' in c.get('subject','')), ''))" 2>/dev/null)
PR_CRED=$(echo $CREDS | python3 -c "import sys,json; creds=json.load(sys.stdin); print(next((c['name'] for c in creds if 'pull_request' in c.get('subject','')), ''))" 2>/dev/null)

check "Federated credential for 'main' branch" "$MAIN_CRED"
check "Federated credential for 'production' environment" "$ENV_CRED"
check "Federated credential for pull requests" "$PR_CRED"

echo ""
echo "🔍 Checking Service Principal..."
SP_ID=$(az ad sp show --id $APP_ID --query id -o tsv 2>/dev/null || true)
check "Service Principal exists" "$SP_ID"

echo ""
echo "🔍 Checking Role Assignments..."
ROLES=$(az role assignment list --assignee $APP_ID --all --query "[].roleDefinitionName" -o tsv 2>/dev/null)
check "At least one role assigned" "$ROLES"

if [ -n "$ROLES" ]; then
  echo "     Roles assigned: $ROLES"
fi

echo ""
echo "🔍 Checking Resource Group..."
RG=$(az group show --name $RESOURCE_GROUP --query name -o tsv 2>/dev/null || true)
check "Resource group '$RESOURCE_GROUP' exists" "$RG"

echo ""
echo "============================================="
echo " Results: $PASS passed, $FAIL failed"
echo "============================================="
echo ""

if [ $FAIL -eq 0 ]; then
  echo "🎉 All checks passed! Your GitHub Actions values:"
  echo ""
  echo "  AZURE_CLIENT_ID       = $APP_ID"
  echo "  AZURE_TENANT_ID       = $TENANT_ID"
  echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
  echo ""
  echo "You can now run your GitHub Actions workflows."
else
  echo "⚠️  $FAIL check(s) failed. Review the errors above."
  echo "   Refer to docs/05-troubleshooting.md for fixes."
  exit 1
fi
