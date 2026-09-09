# fullstack-project-setup

Scaffold a new full-stack project on our locked architecture standard, distilled from lessons learned
on past projects: duplicated business logic between React and React Native, slow `npm` installs, test
coverage that quietly became optional, and architecture rules that got lost as vibe-coded projects
grew.

## Stack

- **Backend:** Python, FastAPI, async SQLAlchemy 2.0 (`asyncpg`), Alembic (async template), Azure
  Database for PostgreSQL Flexible Server.
- **Frontend:** React (web) + React Native (Expo), sharing 90-100% of business logic in an Nx + pnpm
  monorepo. React Native is UI only; React handles HTML rendering only; everything else — data
  fetching, validation, state — lives in shared packages.

## Usage

Ask Claude to "set up a new project" (FastAPI + React + React Native, or similar) — the
`Full-Stack Project Setup` skill triggers automatically and scaffolds the monorepo from its bundled
templates: Nx + pnpm root config, a working `todos` vertical slice end-to-end (FastAPI feature module
→ shared `packages/core`/`packages/hooks` → a React Router page → a React Native screen), enforced
module boundaries, the pre-push + CI 80% coverage gate, the 1000-line file-length lint rule, the
RFC7807 error contract on both sides, and a generated `CLAUDE.md` so a future session in that repo
still knows the architecture without anyone re-invoking the skill.

## What's in the plugin

- **`fullstack-project-setup` skill** — the locked ruleset (`SKILL.md`), full rationale for every
  decision including rejected alternatives (`reference/architecture-decisions.md`), and the real
  boilerplate it scaffolds from (`templates/`).

This is a living skill — as new lessons come up on real projects, the ruleset and templates get
updated here rather than rediscovered per project.

### Install

```shell
/plugin marketplace add suresh-deccansoft/deccansoft-claude-skills
/plugin install fullstack-project-setup@deccansoft-claude-plugins
```

### Support

Questions, issues, or feature requests: **aiteam@deccansoft.net**, or open an issue at
https://github.com/suresh-deccansoft/deccansoft-claude-skills/issues.

### License

MIT.
