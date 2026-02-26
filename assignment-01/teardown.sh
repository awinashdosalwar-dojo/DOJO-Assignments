#!/bin/bash
# =============================================================================
# Teardown Script — Deletes ALL resources in the resource group
# Use with caution! This is irreversible.
#
# Usage: ./teardown.sh --rg rg-myproject-prod
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RESET='\033[0m'

RESOURCE_GROUP="${1:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rg) RESOURCE_GROUP="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$RESOURCE_GROUP" ]]; then
  echo -e "${RED}Usage: $0 --rg <resource-group-name>${RESET}"
  exit 1
fi

echo -e "${RED}⚠️  WARNING: This will permanently delete ALL resources in:${RESET}"
echo -e "${RED}   Resource Group: ${RESOURCE_GROUP}${RESET}"
echo
read -rp "$(echo -e "${YELLOW}Type the resource group name to confirm deletion: ${RESET}")" CONFIRM

if [[ "$CONFIRM" != "$RESOURCE_GROUP" ]]; then
  echo "Confirmation mismatch. Aborting."
  exit 1
fi

echo -e "\n${YELLOW}Deleting resource group: ${RESOURCE_GROUP}...${RESET}"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo -e "${GREEN}Deletion initiated (running in background). Check portal for status.${RESET}"
