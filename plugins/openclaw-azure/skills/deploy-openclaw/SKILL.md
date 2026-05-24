---
name: Deploy OpenClaw to Azure
description: This skill should be used when the user asks to "deploy OpenClaw to Azure", "run OpenClaw on Azure Container Apps", "host my OpenClaw bot on Azure", "set up OpenClaw with Telegram and LiteLLM on Azure", or needs a guided, correct OpenClaw -> Azure Container Apps deployment. Walks through preflight, BuildKit image build in ACR, a persistence choice (cheap local+SMB-sync or premium NFS+VNet), the Container App deploy, and verification — and avoids the Azure Files SMB hard-link trap, the IPv6 egress stall, and the missing gateway.mode failure.
version: 1.0.0
user-invocable: true
allowed-tools: ["Read", "Bash", "AskUserQuestion", "TaskCreate", "TaskUpdate", "TaskList"]
model: sonnet
---

# Deploy OpenClaw to Azure Container Apps

Deploy the OpenClaw gateway to Azure Container Apps: **Telegram via long polling** (outbound only,
so **no public ingress**), **LiteLLM** as an OpenAI-compatible model backend, and a **persistence
choice** the user makes. This skill bakes in fixes for four non-obvious pitfalls — read
`references/gotchas.md` and `references/azure-files-limitations.md` for the full reasoning.

Bundled scripts live at `${CLAUDE_PLUGIN_ROOT}/scripts/`. **Run `az` calls sequentially and never
`kill -9` an `az` process mid-call** (it can corrupt the MSAL token cache). Azure CLI calls can take
a few minutes each in some environments — be patient; prefer running long scripts in the background
and reading their output rather than killing them.

Create one task per phase with `TaskCreate`, mark `in_progress`/`completed` as you go.

## Phase 1 — Preflight

Ask the user for their **ACR (registry) name** first, then run:

```bash
ACR="<acr-name>" bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"
```

This verifies `az` login, the `containerapp` extension, and ACR reachability. If it prints `[FAIL]`,
stop and surface the remediation; do not continue until preflight passes.

## Phase 2 — Collect inputs

Use `AskUserQuestion` (and plain prompts for secrets) to gather:

- **ACR name** and **resource group** (default `openclaw-aca-rg`) and **region** (defaults to the
  ACR's region).
- **LiteLLM**: base URL (must end in `/v1`), API key, and model id (e.g. `azure_ai/gpt-5.4`).
- **Telegram**: bot token from @BotFather, and the **numeric user id** allowed to DM the bot.
- **DM policy**: `allowlist` (recommended — works immediately, no pairing) or `pairing`.
- **OpenClaw source checkout** (`OPENCLAW_REPO`): the local path to an OpenClaw git clone (the build
  context). If the user doesn't have one, offer to clone it:
  `git clone https://github.com/openclaw/openclaw <path>`.

Validate before building (cheap and catches bad inputs):
- LiteLLM: `curl -sS -H "Authorization: Bearer <key>" <base>/models` should list the model.
- Telegram: `curl -sS https://api.telegram.org/bot<token>/getMe` should return `"ok": true`.

**Secrets note:** tell the user that pasting tokens here puts them in the transcript; offer to let
them set the Container App secrets themselves afterward if they prefer. Never write secrets to files
in the repo — they are passed to scripts as environment variables and become Container App secrets.

## Phase 3 — Build the image (BuildKit, in ACR)

OpenClaw's Dockerfile uses `RUN --mount=...`, which the **classic `az acr build` builder rejects**.
Build with BuildKit via the bundled ACR task (also gives a fast cloud network for `pnpm install`):

```bash
ACR="<acr>" OPENCLAW_REPO="<path-to-openclaw>" bash "${CLAUDE_PLUGIN_ROOT}/scripts/build-image.sh"
```

This runs `az acr run` and takes several minutes. Run it and wait for the `push` step to finish;
confirm with `az acr repository show-tags -n <acr> --repository openclaw`.

## Phase 4 — Choose persistence

Before asking, summarize the trade-off (full detail in `references/persistence-options.md` and
`references/azure-files-limitations.md`):

> Conversation memory is otherwise lost on every update/restart. You **cannot** mount Azure Files
> **SMB** at the state dir — OpenClaw's Telegram spool claims updates with hard links and SMB returns
> `ENOTSUP`, silently breaking message processing.

Use `AskUserQuestion` with two options:

- **Local + periodic SMB sync** (recommended default) — state on local disk; a cheap Standard SMB
  share backs it up every 5 min and on shutdown. ~$0–1/mo; a hard crash loses ≤ the last interval.
- **Premium NFS + VNet** — premium Azure Files NFS mounted at the state dir (real-time, no loss).
  ~$15/mo plus a VNet-integrated environment.

## Phase 5 — Deploy

Export the collected inputs as environment variables and run the matching script. Example for the
local+sync path:

```bash
ACR="<acr>" RG="<rg>" LOCATION="<region>" \
TELEGRAM_BOT_TOKEN="<tok>" LITELLM_API_KEY="<key>" LITELLM_BASE_URL="<url/v1>" \
LITELLM_MODEL="<model>" TELEGRAM_ALLOW_FROM="<userid>" DM_POLICY="allowlist" \
bash "${CLAUDE_PLUGIN_ROOT}/scripts/deploy-sync.sh"
```

For the premium path, use `deploy-nfs.sh` with the same env vars. Both scripts are idempotent
(create-or-update), build the Container App with **no ingress**, **single replica**, **forced IPv4**
to Telegram, and **`gateway.mode: local`**. They take several minutes (env + storage creation).

## Phase 6 — Verify

```bash
RG="<rg>" bash "${CLAUDE_PLUGIN_ROOT}/scripts/logs.sh"
```

Confirm `[gateway] ready` and `[telegram] ... polling ingress started` with no `ENOTSUP` or
`fetch timeout`. Then tell the user to **message their bot**. Note that on each future deploy the old
replica briefly conflicts on `getUpdates` while the new one starts — OpenClaw auto-restarts the
channel and recovers in seconds; this is expected (see `references/gotchas.md`).

## If something is wrong

If the bot is silent or slow after deploy, hand off to the **`openclaw-azure-doctor`** agent, which
maps the known symptoms (SMB `ENOTSUP`, IPv6 stall, BuildKit, missing `gateway.mode`) to fixes.
