#!/usr/bin/env bash
# Deploy OpenClaw to Azure Container Apps with PREMIUM AZURE FILES NFS persistence
# (real-time durability, no backup window to lose). NFS 4.1 supports hard links, so the
# Telegram ingress spool works directly on the mounted state dir (no SMB ENOTSUP issue).
#
# This path is heavier and costs more: a premium FileStorage account (~$15/mo minimum at
# the 100 GiB floor) and a VNet-integrated Container Apps environment (NFS has no TLS, so
# it must be reached over a private network). You cannot add a VNet to an existing env, so
# this creates a fresh VNet-integrated environment.
#
# Run az calls strictly sequentially; never kill az mid-call (can corrupt MSAL cache).
#
# Required env: ACR TELEGRAM_BOT_TOKEN LITELLM_API_KEY LITELLM_BASE_URL LITELLM_MODEL
#               TELEGRAM_ALLOW_FROM
# Optional env: RG=openclaw-aca-rg LOCATION=<ACR region> ENV=openclaw-env-nfs
#               APP=openclaw-gateway SA=openclawnfs<rand> DM_POLICY=allowlist
set -euo pipefail
: "${ACR:?}" "${TELEGRAM_BOT_TOKEN:?}" "${LITELLM_API_KEY:?}" "${LITELLM_BASE_URL:?}"
: "${LITELLM_MODEL:?}" "${TELEGRAM_ALLOW_FROM:?}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RG="${RG:-openclaw-aca-rg}"
export ENV="${ENV:-openclaw-env-nfs}"   # fresh, VNet-integrated env
export APP="${APP:-openclaw-gateway}"
export DM_POLICY="${DM_POLICY:-allowlist}"
export STORAGE_MOUNT="${STORAGE_MOUNT:-openclawnfs}"
export PERSIST=nfs
SHARE="${SHARE:-openclaw-state}"
SA="${SA:-openclawnfs$RANDOM}"
VNET="${VNET:-openclaw-vnet}"
SUBNET="${SUBNET:-infra}"
export LOCATION="${LOCATION:-$(az acr show -n "$ACR" --query location -o tsv)}"
export SUB="$(az account show --query id -o tsv)"
export IMAGE="${ACR}.azurecr.io/openclaw:latest"

echo ">> [1/8] Resource group $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

echo ">> [2/8] VNet $VNET + delegated infrastructure subnet $SUBNET (+ Storage service endpoint)"
az network vnet create -g "$RG" -n "$VNET" -l "$LOCATION" \
  --address-prefix 10.30.0.0/16 --subnet-name "$SUBNET" --subnet-prefix 10.30.0.0/23 -o none
az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET" \
  --delegations Microsoft.App/environments --service-endpoints Microsoft.Storage -o none
SUBNET_ID="$(az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET" --query id -o tsv)"

echo ">> [3/8] Premium FileStorage account $SA (NFS; secure-transfer off, network-restricted)"
az storage account create -n "$SA" -g "$RG" -l "$LOCATION" \
  --sku Premium_LRS --kind FileStorage --https-only false \
  --default-action Deny --bypass AzureServices -o none
az storage account network-rule add -g "$RG" --account-name "$SA" --subnet "$SUBNET_ID" -o none

echo ">> [4/8] NFS 4.1 file share $SHARE (premium min 100 GiB)"
az storage share-rm create --storage-account "$SA" -g "$RG" -n "$SHARE" \
  --enabled-protocols NFS --root-squash NoRootSquash --quota 100 -o none

echo ">> [5/8] VNet-integrated Container Apps environment $ENV"
az containerapp env create -n "$ENV" -g "$RG" -l "$LOCATION" \
  --infrastructure-subnet-resource-id "$SUBNET_ID" --logs-destination none -o none

echo ">> [6/8] Link NFS share to the environment"
az containerapp env storage set -g "$RG" -n "$ENV" \
  --storage-name "$STORAGE_MOUNT" --storage-type NfsAzureFile \
  --server "${SA}.file.core.windows.net" --file-share "/${SA}/${SHARE}" \
  --access-mode ReadWrite -o none

echo ">> [7/8] ACR credentials + gateway token + render YAML (persistence: NFS)"
export ACR_USER="$(az acr credential show -n "$ACR" --query username -o tsv)"
export ACR_PASS="$(az acr credential show -n "$ACR" --query "passwords[0].value" -o tsv)"
export GATEWAY_TOKEN="$(openssl rand -hex 32)"
APP_YAML="$(mktemp)"
bash "$SCRIPT_DIR/render-app-yaml.sh" > "$APP_YAML"

echo ">> [8/8] Create or update the Container App"
if az containerapp show -n "$APP" -g "$RG" -o none 2>/dev/null; then
  az containerapp update -n "$APP" -g "$RG" --yaml "$APP_YAML" -o none
else
  az containerapp create -n "$APP" -g "$RG" --yaml "$APP_YAML" -o none
fi
rm -f "$APP_YAML"

echo ">> Done (persistence: premium Azure Files NFS at /home/node/.openclaw)."
echo "   Verify:  bash $SCRIPT_DIR/logs.sh"
