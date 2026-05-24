# OpenClaw on Azure Container Apps — gotchas and fixes

The four traps this plugin exists to solve, plus operational notes.

## 1. The Dockerfile needs BuildKit → `az acr build` fails

OpenClaw's `Dockerfile` uses `RUN --mount=type=bind` and `RUN --mount=type=cache`. The **classic**
Docker builder that `az acr build` uses rejects these:

```
the --mount option requires BuildKit. Refer to https://docs.docker.com/go/buildkit/ ...
```

**Fix:** build with BuildKit. We use an ACR Task (`scripts/acr-buildkit.yaml`) that sets
`DOCKER_BUILDKIT=1` and run it with `az acr run`. Bonus: it builds in-cloud, so the heavy
`pnpm install` runs on a fast network instead of timing out on a slow local link.
(Local `docker build` also works since Docker ≥ 23 enables BuildKit by default, but the cloud build
is more reliable.)

## 2. Azure Files SMB silently breaks message processing

The Telegram ingress spool claims updates with a hard link; SMB returns `ENOTSUP` and the bot goes
silent (receives messages, never replies). **Never mount SMB at the state dir.** Full detail in
`azure-files-limitations.md`. Use local+sync (Standard SMB as a copy-only backup) or premium NFS.

## 3. IPv6 egress to Telegram stalls

On Container Apps, `api.telegram.org` resolves to an IPv6 address whose egress stalls; with Node's
Happy Eyeballs (`autoSelectFamily`) the IPv6 attempt burns ~10–15s before falling back to IPv4. The
symptom is sluggish replies and log lines like:

```
[fetch-timeout] fetch timeout after 10000ms ... url=https://api.telegram.org/...getMe
[telegram] fetch fallback: DNS-resolved IP unreachable; trying alternative Telegram API IP
```

**Fix:** force IPv4 with env vars on the container:

```
OPENCLAW_TELEGRAM_DISABLE_AUTO_SELECT_FAMILY=1
OPENCLAW_TELEGRAM_DNS_RESULT_ORDER=ipv4first
```

(Both are set by the deploy scripts.)

## 4. `gateway.mode: local` is required

Without it the gateway refuses to start:

```
Gateway start blocked: existing config is missing gateway.mode. ...
set gateway.mode=local manually, or pass --allow-unconfigured.
```

**Fix:** the deploy scripts always include `"gateway":{"mode":"local"}` in the rendered config.

## Operational notes

- **No ingress.** Telegram long polling is outbound-only (the documented default), so the Container
  App is created with **ingress disabled** — no public surface. Webhooks would require enabling
  ingress + a validation token; not needed here.
- **Single replica.** Telegram allows only one `getUpdates` consumer, so the app runs `minReplicas:
  maxReplicas: 1`. Don't scale out.
- **`getUpdates` conflict on every deploy.** During a rolling revision swap, the old replica is still
  polling while the new one starts, so Telegram briefly returns
  `Conflict: terminated by other getUpdates request`. OpenClaw auto-restarts the channel (up to 10×)
  and recovers within seconds once the old revision drains. Expected; no action needed.
- **Config delivery.** `openclaw.json` is passed via the `OPENCLAW_CONFIG_JSON` env var and written
  at container startup. It references `${TELEGRAM_BOT_TOKEN}` / `${LITELLM_API_KEY}`, which OpenClaw
  resolves from env at load — so no real secret is baked into the image or config. Real secrets are
  Container App secrets.
- **Slow Azure CLI.** In some environments (e.g. WSL) `az` can take ~3 min per call. Run `az` calls
  **sequentially**; never `kill -9` an in-flight `az` (it can corrupt `~/.azure/msal_token_cache.json`
  and make later auth hang).
