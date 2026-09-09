---
name: fullstack-project-setup
description: >
  Scaffold a new full-stack project on this team's locked architecture standard:
  Python/FastAPI + async SQLAlchemy + Alembic + Azure PostgreSQL backend, React +
  React Native frontend sharing 90-100% of business logic in an Nx + pnpm monorepo,
  with enforced module boundaries, an 80% test-coverage gate, a 1000-line-per-file
  limit, an RFC7807 error contract, and a generated CLAUDE.md so the rules survive
  into every future session in that repo. Use when starting a new project, or on
  any request to "set up a new project", "scaffold a monorepo", "create a new
  FastAPI + React + React Native project", or similar.
---

# Full-Stack Project Setup

This skill is the durable output of a grilling session that fixed a set of
recurring, costly mistakes from past projects: business logic duplicated
between React and React Native, slow npm installs, test coverage that quietly
became optional, and architecture rules that got lost as vibe-coded projects
grew and agents lost context. Every decision below is **locked** for all new
projects unless explicitly re-grilled and changed here.

**This is a living document.** When a decision changes, update this file and
the matching file(s) under `templates/` in the same edit — never let them
drift apart. Full rationale and the honest self-checks/risks for every
decision live in `reference/architecture-decisions.md`; read that before
changing anything, not just this summary.

**Last verified:** 2026-09-09. Pinned tool versions live inline in the
`templates/` files themselves (`package.json`, `pyproject.toml`) — check
those are still current major versions before scaffolding a new project;
static templates go stale silently otherwise.

## Locked architecture (summary)

1. **Monorepo tool:** Nx for the JS/TS side (web + native + shared packages).
   FastAPI stays completely outside the Nx graph — its own folder, own tooling
   (uv/poetry), own CI job. Nx's `enforce-module-boundaries` lint rule is what
   actually stops `apps/native` importing web-only code or vice versa — the
   architecture is enforced by tooling, not memory.
2. **Package manager:** pnpm. Chosen over bun specifically because this stack
   is Nx + React Native + Windows dev machines, where pnpm has the deepest,
   most proven support; bun is faster in isolated benchmarks but stacks three
   less-battle-tested combinations at once (Bun+Nx, Bun+Metro, Bun+Windows).
3. **Code sharing model:** headless core, not universal UI. `packages/core`
   (types, generated API client, zod schemas, pure business rules) and
   `packages/hooks` (all `useX()` orchestration, React Query, forms, no JSX)
   hold every piece of business logic. `apps/web` and `apps/native` contain
   *only* navigation/routing and presentational components. "90-100% shared"
   means business logic — the UI layer is legitimately written twice, once
   per platform, by design.
4. **Env vars:** one root `.env` (real file gitignored, `.env.example`
   committed) is the single source of truth for *values*. Each public/client
   value is duplicated under both bundler-required prefixes (`VITE_FOO` /
   `EXPO_PUBLIC_FOO`, same value) and validated once via a zod schema in
   `packages/env`. Real secrets (DB creds, third-party secret keys) **never**
   go in this file — an RN bundle is fully decompilable/public, so anything
   here is effectively public. A pre-commit check rejects any key added to
   the shared env file that isn't `*_PUBLIC_*`/allowlisted.
5. **Backend DB stack:** SQLAlchemy 2.0 async engine + `asyncpg`, Alembic's
   official **async template** (`alembic init -t async`) driving migrations
   through the same engine. Target: Azure Database for PostgreSQL **Flexible
   Server** (not Single Server, which is retired). Hard rule: never rely on
   implicit lazy-loading on a relationship — always explicit `selectinload`/
   `joinedload`, or it raises `MissingGreenlet` at runtime.
6. **Error contract:** RFC 7807 Problem Details (`application/problem+json`)
   from FastAPI's global exception handlers, with a project-defined
   `errors: [{field, message}]` extension for field-level validation (not
   part of the spec — defined here so it's not reinvented per project). Error
   types are generated into `packages/core` from the OpenAPI schema — never
   hand-maintained. Production responses strip internal detail/stack traces;
   dev responses include them.
7. **Async data/loading state:** TanStack Query in `packages/hooks` is the
   single source of truth for all async state, called with an identical hook
   from both a React page and a React Native screen. React Router `loader()`
   functions are allowed on web *only* as a thin (1-3 line) adapter around a
   shared query definition (`queryClient.ensureQueryData(sharedQueryOptions)`)
   — the real fetch logic is never duplicated; only the trigger (router
   lifecycle vs. component mount) differs per platform.
8. **Coverage gate:** 80% lines+branches, repo-wide (greenfield default —
   diff-coverage is a documented fallback if this skill is ever used to
   retrofit an existing codebase, not the default). Enforced in layers: a
   **pre-push** git hook runs `nx affected -t test --coverage` + `pytest
   --cov` as fast local feedback; **CI is the real, non-bypassable gate**;
   the pipeline is ordered so build/deploy never runs unless the test+
   coverage stage passed. Coverage is never embedded directly inside the
   build command itself.
9. **1000-line file limit:** hard lint-level error, wired into the same
   pre-push+CI gate — ESLint `max-lines` (TS/JS) and a small `pre-commit`
   Python script (`scripts/check_file_length.py`) for the backend. Generated/
   vendored files are exempt via an editable glob list — **you can add
   exceptions**; it's a maintained allowlist, not a rigid rule.
10. **Test runners:** Vitest for the web app **and** for shared packages
    (`packages/core`, `packages/hooks` have no native-module dependency, so
    they don't need Jest). Jest (`jest-expo` preset) is scoped *only* to
    `apps/native`'s own platform-specific code. Coverage from both merges
    into one repo-wide 80% figure. ESLint restricts `jest` globals to
    `apps/native` so agents don't reflexively write Jest-style mocks in
    shared packages.
11. **Backend folder structure:** domain/feature-based vertical modules —
    `app/features/<domain>/{router.py, service.py, repository.py, schemas.py,
    models.py, tests/}` — FastAPI's own recommended "bigger applications"
    pattern. Cross-cutting concerns (auth, db session, config) live in
    `app/core/`, never duplicated per-domain.
12. **Skill packaging:** this skill is `SKILL.md` + real boilerplate under
    `templates/`, not prose the agent regenerates from memory each time.
    Regenerating boilerplate from memory each time is the failure mode this
    skill exists to remove.
13. **Ongoing memory:** every scaffolded project gets a generated
    `CLAUDE.md` (from `templates/root/CLAUDE.md.template`) summarizing these
    rules, so a Claude Code session opened in that repo months from now still
    knows the architecture without anyone re-invoking this skill. `CLAUDE.md`
    carries the "why" (so agents propose correct code the first time); the
    enforced tooling in items 8-10 is the hard backstop that catches it if
    they don't.
14. **Cross-platform dependency version divergence:** React Native
    legitimately pins tighter/older versions of core packages (React itself,
    polyfills) than web — that's normal, not a bug to force-fix into one
    version. Two cases:
    - *Same package, different version* (e.g. React): `packages/core` and
      `packages/hooks` declare it as a **`peerDependency` with a broad range**
      (`"react": "^18.2.0 || ^19.0.0"`), never a pinned regular `dependency`.
      pnpm resolves that peer independently per consumer's own isolated
      dependency tree, so `apps/web`'s and `apps/native`'s versions never
      collide; each app keeps its own exact pin in its own `package.json`.
      Never hoist a platform-sensitive version to the workspace root.
    - *Not actually the same package* — genuinely platform-only libraries
      doing the same job (`@react-native-async-storage/async-storage` vs.
      `localStorage`/`idb-keyval`; native gesture/animation libs). Shared
      logic never imports either directly — it defines a small interface and
      each app injects its own platform implementation. This falls straight
      out of decision 3: if shared logic seems to need a platform-only
      package, that's a sign the logic isn't actually platform-agnostic yet,
      not a reason to compromise the shared-package boundary.
    - Enforcement: pnpm warns/errors on unmet peer-dependency ranges at
      `pnpm install` time automatically — the backstop, not a manual check.

## When invoked (scaffolding a new project)

1. **Ask only what's genuinely project-specific** — project name, initial
   domain/feature beyond the bundled `todo` reference slice, Azure resource
   naming if known. Do not re-litigate anything in the locked list above;
   if the user wants to change one of those, that's a re-grill of this
   skill, not a one-off deviation for a single project (see "Maintaining
   this skill" below).
2. Create the target directory and copy the entire `templates/` tree into
   it, preserving structure (`templates/root/*` → project root,
   `templates/packages/*` → `packages/*`, `templates/apps/*` → `apps/*`,
   `templates/backend/*` → `backend/*`, `templates/eslint/*` → wherever the
   root ESLint config references it).
3. Replace placeholders in every copied file: `{{PROJECT_NAME}}`,
   `{{PROJECT_SLUG}}` (kebab-case), `{{DB_NAME}}`, `{{AZURE_RESOURCE_GROUP}}`
   (leave a clear `TODO` if not yet known — never invent an Azure resource
   name silently).
4. Rename the bundled `todos` feature slice (backend `app/features/todos`,
   `packages/hooks/src/queries/todos.ts`, the web route and native screen) to
   the project's actual first domain if the user gave one; otherwise leave
   `todos` in place as the working reference example — it exists specifically
   to demonstrate the full pattern end-to-end (shared query → thin web loader
   adapter → native screen → FastAPI vertical slice → Alembic migration).
5. `pnpm install`, `git init`, `pre-commit install` (installs the pre-push
   hook), install the Python backend's dependencies (uv/poetry per
   `pyproject.toml`).
6. **Smoke-test the scaffold before declaring done:** run the web and
   backend test suites (they should pass with the bundled `todos` slice's
   tests), run the lint/module-boundary check, run the file-length check.
   A skill that scaffolds a broken starting point is worse than no skill.
7. Report manual follow-ups explicitly rather than silently skipping them:
   Azure PostgreSQL Flexible Server provisioning, real secrets (never
   generated), CI secrets configuration in the Git host, and anything left
   as `TODO` from step 3.

## Maintaining this skill

You will keep using this skill across projects and keep updating it. When a
new lesson comes up on a real project:

- Decide whether it's a **global rule change** (update this file +
  `reference/architecture-decisions.md` + the relevant `templates/` file, so
  every future project gets it) or a **one-off for that project only** (does
  not touch this skill).
- If it's a global change that reverses or meaningfully qualifies a locked
  decision above, treat it as worth a fresh grilling pass (`grill-design`)
  before editing, the same way this skill was built — don't silently
  overwrite a locked decision based on one project's pressure without
  checking it against the other 12.
- Bump the "Last verified" date at the top of this file whenever you touch
  it, and re-check pinned versions in `templates/` at the same time.
