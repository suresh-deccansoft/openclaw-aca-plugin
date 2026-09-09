# Deccansoft Claude Code plugins

A Claude Code [plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces). Currently
ships two plugins:

- [`openclaw-azure`](#openclaw-azure--deploy-openclaw-to-azure-container-apps) — deploy OpenClaw to
  Azure Container Apps.
- [`fullstack-project-setup`](#fullstack-project-setup--scaffold-a-fastapi--react--react-native-monorepo)
  — scaffold a new FastAPI + React + React Native monorepo on our locked architecture.

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

## `fullstack-project-setup` — scaffold a FastAPI + React + React Native monorepo

Scaffolds a new full-stack project on our locked architecture standard, distilled from lessons
learned on past projects: duplicated business logic between React and React Native, slow `npm`
installs, test coverage that quietly became optional, and architecture rules that got lost as
vibe-coded projects grew.

**Stack:** Python/FastAPI + async SQLAlchemy 2.0 + Alembic + Azure Database for PostgreSQL Flexible
Server on the backend; React (web) + React Native (Expo) sharing 90-100% of business logic in an
Nx + pnpm monorepo, where React Native is UI only and React handles HTML rendering only.

### Install

```shell
/plugin marketplace add suresh-deccansoft/deccansoft-claude-skills
/plugin install fullstack-project-setup@deccansoft-claude-plugins
```

Then just ask Claude to "set up a new project" (FastAPI + React + React Native) — the
`fullstack-project-setup` skill triggers automatically.

### What's in the plugin

- **`fullstack-project-setup` skill** — the locked ruleset (`SKILL.md`), full rationale for every
  decision including rejected alternatives
  ([`reference/architecture-decisions.md`](plugins/fullstack-project-setup/skills/fullstack-project-setup/reference/architecture-decisions.md)),
  and the real boilerplate it scaffolds from (`templates/`): Nx + pnpm root config, a working `todos`
  vertical slice end-to-end, enforced module boundaries, the pre-push + CI 80% coverage gate, the
  1000-line file-length lint rule, an RFC7807 error contract on both sides, and a generated
  `CLAUDE.md` so a future session in that repo still knows the architecture without anyone
  re-invoking the skill.

### Support

Questions, issues, or feature requests: **aiteam@deccansoft.net**, or open an issue at
https://github.com/suresh-deccansoft/deccansoft-claude-skills/issues.

### License

MIT.
