#!/usr/bin/env bash
# Preflight checks for an OpenClaw -> Azure Container Apps deploy.
# Verifies az login, the containerapp extension, ACR reachability, and (if building
# locally) Docker. Prints actionable remediation and exits non-zero on hard failures.
#
# Env: ACR (registry name, required), BUILD_LOCAL (1 if building with local Docker).
set -uo pipefail
fail=0

echo "== OpenClaw Azure preflight =="

# 1. Azure CLI logged in
if acct=$(az account show --query "{sub:name,user:user.name}" -o tsv 2>/dev/null); then
  echo "  [ok] az logged in: $acct"
else
  echo "  [FAIL] az is not logged in. Run:  az login"
  fail=1
fi

# 2. containerapp extension
if az extension show -n containerapp -o none 2>/dev/null; then
  echo "  [ok] az containerapp extension installed"
else
  echo "  [warn] containerapp extension missing. Install:  az extension add -n containerapp"
fi

# 3. ACR reachable
if [ -n "${ACR:-}" ]; then
  if login=$(az acr show -n "$ACR" --query loginServer -o tsv 2>/dev/null); then
    echo "  [ok] ACR reachable: $login"
  else
    echo "  [FAIL] ACR '$ACR' not found in this subscription."
    fail=1
  fi
else
  echo "  [warn] ACR not set yet (will be collected during the wizard)."
fi

# 4. Docker only matters if building locally (default builds in ACR with BuildKit)
if [ "${BUILD_LOCAL:-0}" = "1" ]; then
  if docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
    echo "  [ok] Docker daemon up: $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
  else
    echo "  [FAIL] Docker daemon not reachable but BUILD_LOCAL=1. Start Docker or build in ACR."
    fail=1
  fi
else
  echo "  [ok] Building in ACR (no local Docker required)."
fi

if [ "$fail" -ne 0 ]; then
  echo "== preflight FAILED — fix the [FAIL] items above before deploying. =="
  exit 1
fi
echo "== preflight OK =="
