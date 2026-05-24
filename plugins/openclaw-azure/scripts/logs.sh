#!/usr/bin/env bash
# Tail the OpenClaw gateway console logs and highlight the health signals:
# "[gateway] ready", telegram polling start, and any of the known failure signatures
# (ENOTSUP hard-link spool, IPv6 fetch timeout, missing gateway.mode).
#
# Optional env: RG=openclaw-aca-rg APP=openclaw-gateway TAIL=150 FOLLOW=0
set -uo pipefail
RG="${RG:-openclaw-aca-rg}"
APP="${APP:-openclaw-gateway}"
TAIL="${TAIL:-150}"

if [ "${FOLLOW:-0}" = "1" ]; then
  exec az containerapp logs show -n "$APP" -g "$RG" --type console --follow
fi

az containerapp logs show -n "$APP" -g "$RG" --type console --tail "$TAIL" 2>&1 \
  | grep -vE "Connecting to container|Successfully Connected to" \
  | grep -iE "ready|telegram|spool|litellm|error|ENOTSUP|fetch timeout|gateway.mode|model config|conflict" \
  | tail -40
