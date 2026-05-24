#!/usr/bin/env bash
# Emit the Azure Container App YAML for the OpenClaw gateway to stdout.
# Shared by deploy-sync.sh and deploy-nfs.sh. Driven entirely by env vars.
#
# PERSIST selects the persistence strategy:
#   sync : live state on local disk; a Standard SMB share mounted at $BACKUP_PATH;
#          start command restores on boot, backs up every 5 min + on SIGTERM
#          (excludes the telegram hard-link spool + logs). Cheap, ~<=5min crash loss.
#   nfs  : premium Azure Files NFS mounted directly at the state dir. NFS supports
#          hard links, so the telegram spool works in place. Real-time durability.
#
# Required env (all modes): LOCATION RG ENV APP IMAGE SUB ACR ACR_USER ACR_PASS
#   GATEWAY_TOKEN TELEGRAM_BOT_TOKEN LITELLM_API_KEY LITELLM_BASE_URL LITELLM_MODEL
#   TELEGRAM_ALLOW_FROM DM_POLICY STORAGE_MOUNT PERSIST
# Mode 'sync' also uses: BACKUP_PATH (default /mnt/state-backup)
set -euo pipefail

: "${PERSIST:?set PERSIST=sync|nfs}"
: "${LOCATION:?}" "${RG:?}" "${ENV:?}" "${APP:?}" "${IMAGE:?}" "${SUB:?}" "${ACR:?}"
: "${ACR_USER:?}" "${ACR_PASS:?}" "${GATEWAY_TOKEN:?}"
: "${TELEGRAM_BOT_TOKEN:?}" "${LITELLM_API_KEY:?}" "${LITELLM_BASE_URL:?}" "${LITELLM_MODEL:?}"
: "${TELEGRAM_ALLOW_FROM:?}" "${STORAGE_MOUNT:?}"
DM_POLICY="${DM_POLICY:-allowlist}"
BACKUP_PATH="${BACKUP_PATH:-/mnt/state-backup}"

# OpenClaw config. gateway.mode=local is REQUIRED or the gateway refuses to start.
# ${TELEGRAM_BOT_TOKEN}/${LITELLM_API_KEY} are resolved by OpenClaw from env at load
# (parseEnvTemplateSecretRef), so no real secret is baked into the config string.
CONFIG_JSON=$(cat <<JSON
{"gateway":{"mode":"local"},"channels":{"telegram":{"enabled":true,"botToken":"\${TELEGRAM_BOT_TOKEN}","dmPolicy":"${DM_POLICY}","allowFrom":["${TELEGRAM_ALLOW_FROM}"],"groups":{"*":{"requireMention":true}}}},"models":{"providers":{"litellm":{"baseUrl":"${LITELLM_BASE_URL}","apiKey":"\${LITELLM_API_KEY}","api":"openai-completions","models":[{"id":"${LITELLM_MODEL}","name":"LiteLLM ${LITELLM_MODEL}"}]}}},"agents":{"defaults":{"model":{"primary":"litellm/${LITELLM_MODEL}"}}}}
JSON
)

# Per-mode container args (start command) and volume block.
if [ "$PERSIST" = "sync" ]; then
  IFS= read -r -d '' ARGS_BLOCK <<ARGS || true
          - |
            set +e
            BK=${BACKUP_PATH}
            ST="\$OPENCLAW_STATE_DIR"
            mkdir -p "\$ST" "\$BK"
            # Restore persisted state from the backup share (telegram spool/logs excluded)
            for entry in "\$BK"/*; do
              case "\$(basename "\$entry")" in telegram|logs) continue ;; esac
              cp -ru "\$entry" "\$ST"/ 2>/dev/null || true
            done
            # Config is authoritative from env; write last so it always wins
            printf "%s" "\$OPENCLAW_CONFIG_JSON" > "\$OPENCLAW_CONFIG_PATH"
            # Back up state EXCEPT the hard-link telegram spool (SMB can't link()) and logs
            sync_state() {
              for entry in "\$ST"/*; do
                case "\$(basename "\$entry")" in telegram|logs) continue ;; esac
                cp -ru "\$entry" "\$BK"/ 2>/dev/null || true
              done
            }
            # Final sync on graceful shutdown (ACA sends SIGTERM before stopping a revision)
            trap 'sync_state; kill -TERM "\$GW" 2>/dev/null; wait "\$GW" 2>/dev/null; exit 0' TERM INT
            ( while true; do sleep 300; sync_state; done ) &
            node dist/index.js gateway --bind loopback --port 18789 &
            GW=\$!
            wait "\$GW"
ARGS
  IFS= read -r -d '' VOLUME_BLOCK <<VOL || true
        volumeMounts:
          - volumeName: state-backup
            mountPath: ${BACKUP_PATH}
    volumes:
      - name: state-backup
        storageType: AzureFile
        storageName: ${STORAGE_MOUNT}
VOL
else
  # nfs: state dir is the durable mount; spool hard links work natively.
  IFS= read -r -d '' ARGS_BLOCK <<ARGS || true
          - 'mkdir -p "\$OPENCLAW_CONFIG_DIR" && printf "%s" "\$OPENCLAW_CONFIG_JSON" > "\$OPENCLAW_CONFIG_PATH" && exec node dist/index.js gateway --bind loopback --port 18789'
ARGS
  IFS= read -r -d '' VOLUME_BLOCK <<VOL || true
        volumeMounts:
          - volumeName: state
            mountPath: /home/node/.openclaw
    volumes:
      - name: state
        storageType: NfsAzureFile
        storageName: ${STORAGE_MOUNT}
VOL
fi

cat <<YAML
location: ${LOCATION}
name: ${APP}
type: Microsoft.App/containerApps
properties:
  managedEnvironmentId: /subscriptions/${SUB}/resourceGroups/${RG}/providers/Microsoft.App/managedEnvironments/${ENV}
  configuration:
    activeRevisionsMode: Single
    secrets:
      - name: telegram-bot-token
        value: "${TELEGRAM_BOT_TOKEN}"
      - name: litellm-api-key
        value: "${LITELLM_API_KEY}"
      - name: gateway-token
        value: "${GATEWAY_TOKEN}"
      - name: acr-password
        value: "${ACR_PASS}"
    registries:
      - server: ${ACR}.azurecr.io
        username: ${ACR_USER}
        passwordSecretRef: acr-password
  template:
    containers:
      - name: ${APP}
        image: ${IMAGE}
        resources:
          cpu: 1.0
          memory: 2.0Gi
        command: ["/bin/sh", "-c"]
        args:
${ARGS_BLOCK}
        env:
          - name: HOME
            value: /home/node
          - name: OPENCLAW_HOME
            value: /home/node
          - name: OPENCLAW_STATE_DIR
            value: /home/node/.openclaw
          - name: OPENCLAW_CONFIG_DIR
            value: /home/node/.openclaw
          - name: OPENCLAW_CONFIG_PATH
            value: /home/node/.openclaw/openclaw.json
          - name: OPENCLAW_WORKSPACE_DIR
            value: /home/node/.openclaw/workspace
          - name: OPENCLAW_DISABLE_BONJOUR
            value: "1"
          # Force IPv4 to api.telegram.org (ACA IPv6 egress stalls ~10-15s/call otherwise)
          - name: OPENCLAW_TELEGRAM_DISABLE_AUTO_SELECT_FAMILY
            value: "1"
          - name: OPENCLAW_TELEGRAM_DNS_RESULT_ORDER
            value: "ipv4first"
          - name: NODE_OPTIONS
            value: --max-old-space-size=1536
          - name: TELEGRAM_BOT_TOKEN
            secretRef: telegram-bot-token
          - name: LITELLM_API_KEY
            secretRef: litellm-api-key
          - name: OPENCLAW_GATEWAY_TOKEN
            secretRef: gateway-token
          - name: OPENCLAW_CONFIG_JSON
            value: '${CONFIG_JSON}'
${VOLUME_BLOCK}
    scale:
      minReplicas: 1
      maxReplicas: 1
YAML
