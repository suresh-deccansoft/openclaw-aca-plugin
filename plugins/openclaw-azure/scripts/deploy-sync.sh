#!/usr/bin/env bash
# Deploy OpenClaw to Azure Container Apps with the LOCAL-DISK + PERIODIC-SMB-BACKUP
# persistence model (cheap, ~<=5min crash loss). The live state dir stays on local
# disk so the Telegram spool's hard-link claim works; a Standard SMB share is mounted
# at $BACKUP_PATH and the container restores on boot + backs up every 5 min + on SIGTERM.
#
# Run az calls strictly sequentially; never kill az mid-call (can corrupt MSAL cache).
#
# Required env: ACR TELEGRAM_BOT_TOKEN LITELLM_API_KEY LITELLM_BASE_URL LITELLM_MODEL
#               TELEGRAM_ALLOW_FROM
# Optional env (defaults shown): RG=openclaw-aca-rg LOCATION=<ACR region> ENV=openclaw-env
#               APP=openclaw-gateway SA=openclawaca<rand> DM_POLICY=allowlist
set -euo pipefail
: "${ACR:?}" "${TELEGRAM_BOT_TOKEN:?}" "${LITELLM_API_KEY:?}" "${LITELLM_BASE_URL:?}"
: "${LITELLM_MODEL:?}" "${TELEGRAM_ALLOW_FROM:?}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RG="${RG:-openclaw-aca-rg}"
export ENV="${ENV:-openclaw-env}"
export APP="${APP:-openclaw-gateway}"
export DM_POLICY="${DM_POLICY:-allowlist}"
export STORAGE_MOUNT="${STORAGE_MOUNT:-openclawstate}"
export BACKUP_PATH="${BACKUP_PATH:-/mnt/state-backup}"
export PERSIST=sync
SHARE="${SHARE:-openclaw-state}"
SA="${SA:-openclawaca$RANDOM}"
# Default region to the ACR's region for low pull latency.
export LOCATION="${LOCATION:-$(az acr show -n "$ACR" --query location -o tsv)}"
export SUB="$(az account show --query id -o tsv)"
export IMAGE="${ACR}.azurecr.io/openclaw:latest"

echo ">> [1/6] Resource group $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

echo ">> [2/6] Standard storage account $SA + file share $SHARE (cheap backup target)"
az storage account create -n "$SA" -g "$RG" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 -o none
SA_KEY="$(az storage account keys list -n "$SA" -g "$RG" --query "[0].value" -o tsv)"
az storage share-rm create --storage-account "$SA" -g "$RG" -n "$SHARE" --quota 5 -o none

echo ">> [3/6] Container Apps environment $ENV + SMB storage link"
az containerapp env create -n "$ENV" -g "$RG" -l "$LOCATION" --logs-destination none -o none
az containerapp env storage set -g "$RG" -n "$ENV" \
  --storage-name "$STORAGE_MOUNT" \
  --azure-file-account-name "$SA" --azure-file-account-key "$SA_KEY" \
  --azure-file-share-name "$SHARE" --access-mode ReadWrite -o none

echo ">> [4/6] ACR pull credentials + gateway token"
export ACR_USER="$(az acr credential show -n "$ACR" --query username -o tsv)"
export ACR_PASS="$(az acr credential show -n "$ACR" --query "passwords[0].value" -o tsv)"
export GATEWAY_TOKEN="$(openssl rand -hex 32)"

echo ">> [5/6] Render Container App YAML (persistence: local + periodic SMB sync)"
APP_YAML="$(mktemp)"
bash "$SCRIPT_DIR/render-app-yaml.sh" > "$APP_YAML"

echo ">> [6/6] Create or update the Container App"
if az containerapp show -n "$APP" -g "$RG" -o none 2>/dev/null; then
  az containerapp update -n "$APP" -g "$RG" --yaml "$APP_YAML" -o none
else
  az containerapp create -n "$APP" -g "$RG" --yaml "$APP_YAML" -o none
fi
rm -f "$APP_YAML"

echo ">> Done (persistence: local + periodic SMB backup on $SA/$SHARE)."
echo "   Verify:  bash $SCRIPT_DIR/logs.sh"
