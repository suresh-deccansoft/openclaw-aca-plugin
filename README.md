# Deccansoft Claude Code plugins

A Claude Code [plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces). Currently
ships one plugin:

## `openclaw-azure` — deploy OpenClaw to Azure Container Apps

A guided deploy wizard that gets [OpenClaw](https://github.com/openclaw/openclaw) running on
**Azure Container Apps** correctly the first time — packaging a set of non-obvious pitfalls we hit
the hard way so you don't have to.

### Why this exists

Deploying OpenClaw to ACA looks simple but has four traps that each cost real time:

1. **The image needs BuildKit.** OpenClaw's `Dockerfile` uses `RUN --mount=...`, which the classic
   builder behind `az acr build` rejects. You must build with BuildKit (we do it in-cloud via an ACR
   task, which also gives a fast network for the heavy `pnpm install`).
2. **Azure Files SMB silently breaks the bot.** OpenClaw's Telegram ingress spool claims each update
   with a hard link (`link()`). SMB file shares don't support hard links and return
   `ENOTSUP` — so messages are *received but never processed*, and the bot goes silent with no obvious
   error. Mounting an SMB share at the state dir is the natural thing to do, and it's wrong.
3. **Container Apps IPv6 egress to `api.telegram.org` stalls**, adding ~10–15s to every Telegram call
   until a fallback kicks in. You must force IPv4.
4. **`gateway.mode: local` is mandatory** or the gateway refuses to start.

This plugin encodes all of that into a `/openclaw-azure:deploy` wizard, a troubleshooting agent, and
reference docs.

### Persistence: you choose

The wizard asks how you want conversation memory to survive updates/restarts:

| Model | Memory survives restart | Crash loss | Extra cost | What the wizard does |
|---|---|---|---|---|
| **Local + periodic sync** (default) | ✅ (final sync on SIGTERM) | ≤ last sync interval on a hard crash | ~$0–1/mo (Standard SMB) | Keeps state on local disk (hard links work) and backs it up to a cheap SMB share every 5 min + on shutdown |
| **Premium NFS + VNet** | ✅ real-time | none | ~$15/mo + VNet | Provisions premium Azure Files NFS (NFS 4.1 supports hard links) and a VNet-integrated environment, mounted directly at the state dir |

See [`plugins/openclaw-azure/skills/deploy-openclaw/references/azure-files-limitations.md`](plugins/openclaw-azure/skills/deploy-openclaw/references/azure-files-limitations.md)
for the full explanation of why SMB can't back the state dir.

### Install

```shell
/plugin marketplace add suresh-deccansoft/openclaw-aca-plugin
/plugin install openclaw-azure@deccansoft-claude-plugins
```

Then run:

```shell
/openclaw-azure:deploy
```

### What's in the plugin

- **`/openclaw-azure:deploy`** — phased deploy wizard (preflight → inputs → BuildKit build → persistence choice → deploy → verify).
- **`openclaw-azure-doctor`** agent — diagnoses a silent or broken deployment from the logs.
- **Reference docs** — Azure Files limitations, persistence comparison, and the full gotchas list.
- **Bundled scripts** — preflight, BuildKit build, both deploy paths, and log verification.

### Support

Questions, issues, or feature requests: **aiteam@deccansoft.net**, or open an issue at
https://github.com/suresh-deccansoft/openclaw-aca-plugin/issues.

Privacy: see [PRIVACY.md](PRIVACY.md) — the plugin collects no data and sends nothing to its authors.

### License

MIT.
