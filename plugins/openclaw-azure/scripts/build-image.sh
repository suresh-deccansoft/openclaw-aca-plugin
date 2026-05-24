#!/usr/bin/env bash
# Build + push the OpenClaw image to ACR using BuildKit (in-cloud ACR task).
# OpenClaw's Dockerfile uses RUN --mount, which the classic `az acr build` builder
# rejects; the ACR task here sets DOCKER_BUILDKIT=1. Building in-cloud also avoids
# local pnpm-install network timeouts.
#
# Env:
#   ACR           required, registry name (e.g. myacr)
#   OPENCLAW_REPO required, path to a local OpenClaw checkout (the build context)
set -euo pipefail
: "${ACR:?set ACR (registry name)}"
: "${OPENCLAW_REPO:?set OPENCLAW_REPO (path to an OpenClaw git checkout)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Normalize a Windows-style CLAUDE_PLUGIN_ROOT if present (harmless on POSIX).
TASK_YAML="${SCRIPT_DIR}/acr-buildkit.yaml"

if [ ! -f "${OPENCLAW_REPO}/Dockerfile" ]; then
  echo "ERROR: no Dockerfile at ${OPENCLAW_REPO}. Point OPENCLAW_REPO at an OpenClaw checkout." >&2
  exit 1
fi

echo ">> Building openclaw:latest in ACR '$ACR' with BuildKit (this takes several minutes)..."
# Run from the repo so the build context '.' is the OpenClaw checkout; the task file
# is passed by absolute path.
( cd "$OPENCLAW_REPO" && az acr run -r "$ACR" -f "$TASK_YAML" . )
echo ">> Build pushed: ${ACR}.azurecr.io/openclaw:latest"
