# Architecture Decisions — Full Rationale

This is the source of truth for *why* each rule in `SKILL.md` exists,
including the self-checks/risks raised when each was decided. `SKILL.md`
is the condensed operational summary; this file is what you re-read before
changing a locked decision.

## 1. Monorepo tool: Nx

**Problem it solves:** the recurring complaint — "architecture rules get
lost as the project grows / agents vibe-code without remembering" — needs a
mechanism that fails the build on violation, not a convention someone has to
remember. Nx's `enforce-module-boundaries` ESLint rule, driven by project
tags, does exactly that: tag `apps/native` and `apps/web` as `type:app`,
`packages/core`/`packages/hooks` as `type:logic`, and forbid `type:app`
importing another `type:app`, or anything importing "up" the dependency
direction. A bad import fails lint/CI, it doesn't just go unreviewed.

**Rejected:** Turborepo (great caching, but no boundary enforcement — you'd
hand-roll and maintain the import-restriction rules yourself); plain pnpm
workspaces with no orchestrator (zero enforcement, relies entirely on
discipline).

**Risk accepted:** Nx adds real config surface (`nx.json`, per-project
`project.json`, tags) that can itself be misconfigured — you can trade
"architecture drift" for "Nx-config drift" if tags aren't kept accurate as
packages are added. Python/FastAPI support in Nx is a community plugin, not
official and not mature enough to trust — so the backend is deliberately
**outside** the Nx graph entirely, with its own tooling and CI job.

## 2. Package manager: pnpm

**Analysis vs. bun** (the user had reservations about bun and asked for
this explicitly):

| | pnpm | bun |
|---|---|---|
| Install speed vs npm | ~2-3x faster | ~5-20x faster |
| Nx official support | first-class, most documented | supported, newer |
| React Native + Metro | known friction, well-documented fixes (`nodeLinker=hoisted` or Metro exports config) | thinner track record — Bun's own linking-strategy changes have caused separate Metro resolution issues; Metro itself still runs on Node regardless, so Bun's runtime speed doesn't reach the RN bundling step anyway |
| Windows support | mature | newer, historically the roughest of the two on Windows |

**Decision:** pnpm — it already solves the actual stated complaint (npm is
slow) with a large proven margin, and is the safer match for this exact
stack (Nx + React Native + Windows dev machines). Bun's extra speed mostly
helps web/CI install time, not the RN dev loop, and stacks three
less-proven combinations (Bun+Nx, Bun+Metro, Bun+Windows) at once.

**Not closed forever:** if CI install time at scale becomes a real cost,
piloting bun in CI only (not local dev) is a reasonable future revisit —
this wasn't rejected because bun is bad, but because pnpm is the safer
default *right now* for *this* stack.

## 3. Code sharing model: headless core, not universal UI

**The user's own framing** — "React Native will have only UI related logic,
React will have HTML rendering logic" — already picks this option: it treats
web and native as two separate rendering targets, not one unified component
tree.

**Structure:**
- `packages/core` — types, generated API client, zod schemas, pure business
  rules/state machines. No JSX, no React import even.
- `packages/hooks` — all `useX()` orchestration: React Query, form logic,
  validation wiring. No JSX.
- `apps/web`, `apps/native` — navigation/routing + presentational
  components only. Call into `packages/hooks`, never reimplement logic.

**Rejected:** React Native Web / universal UI (Tamagui, NativeWind,
Dripsy + Solito) — would get higher *total* shared-code % (UI included, not
just logic) but means re-platforming the entire rendering approach and
contradicts the user's explicit two-rendering-targets framing.

**Honest scope:** "90-100% shared" means business logic. UI code
(components, screens, styling) is legitimately written twice, once per
platform — that duplication is permanent and accepted under this model, not
a gap to close later.

## 4. Common `.env` for web + mobile

**Reality:** neither Vite nor Expo reads a raw `.env` at runtime — both
inline env vars into the bundle at build time, and both require a specific
prefix (`VITE_*` / `EXPO_PUBLIC_*`) to pick a var up at all. An RN bundle is
fully decompilable/extractable, so anything in it is effectively public.

**Decision:** one root `.env` (gitignored) is the single source of truth for
*values*; `.env.example` is committed. Each public config value is
duplicated under both required prefixes (same value, two keys —
`VITE_API_BASE_URL` / `EXPO_PUBLIC_API_BASE_URL`). A `packages/env` package
holds a zod schema validating the file once; both apps import the typed,
validated result instead of reading `process.env` directly.

**Hard rule, not just convention:** real secrets (DB credentials, third-
party secret keys) never go in this file — a pre-commit check rejects any
new key in the shared env file that isn't `*_PUBLIC_*`/explicitly
allowlisted, because "it's labeled common" is exactly the kind of mistake a
vibe-coding agent will make under this file's existence otherwise.

## 5. Backend DB stack: async SQLAlchemy + Alembic async template

**Decision:** SQLAlchemy 2.0 async engine + `asyncpg`, Alembic's official
async template (`alembic init -t async`, using `run_sync` internally),
targeting **Azure Database for PostgreSQL Flexible Server** (Single Server
is retired — never scaffold against it).

**Rejected:** separate sync engine (psycopg2) just for Alembic — works, but
two DB drivers/configs to keep in sync for no real benefit once the async
template exists; sync SQLAlchemy + FastAPI threadpool — simpler, but
directly contradicts "async by nature."

**Hard rule:** never rely on implicit lazy-loading on a relationship in
async context — it raises `MissingGreenlet` at runtime, not at write time.
Always explicit `selectinload`/`joinedload`. This must be in the backend
template's example code, not just documented, or agents will hit it
constantly without knowing why.

## 6. Error contract: RFC 7807 Problem Details

**Decision:** every backend error (validation, HTTP, unhandled 500)
normalizes to `application/problem+json`
(`{type, title, status, detail, instance, ...extensions}`) via FastAPI
global exception handlers. Error *types* are generated into `packages/core`
directly from the OpenAPI schema (`openapi-typescript`/`orval`) — never
hand-maintained, so frontend error shapes can't silently drift from backend
reality. A single `ApiError` class + `parseApiError()` in `packages/core` is
what both React and React Native actually catch; only the presentation
(toast vs. native alert, HTML vs. RN error boundary) differs per platform.

**Two things defined here that aren't part of the RFC 7807 spec itself, and
would otherwise be reinvented inconsistently per project:**
- Field-level validation shape: an `errors: [{field, message}]` extension
  array, since Problem Details is about request-level errors, not
  per-field granularity.
- Production vs. dev detail suppression: the global handler must strip
  stack traces/internal detail in production responses — hard-coded branch
  in the template, not a reminder in a doc.

## 7. Async data/loading state: TanStack Query owns it, loaders are a thin adapter

**The tension:** React Router's route `loader()` is a web-only routing
concept — React Navigation has no equivalent. If shared logic must behave
identically on both platforms (decision 3), route loaders can't be *where*
the real fetch logic lives.

**Decision:** TanStack Query, living in `packages/hooks`, is the single
source of truth for all async state — called with an identical hook and
contract from a React page component and a React Native screen component.
On web, a React Router `loader()` is allowed, but only as a thin (1-3 line)
adapter: `loader: () => queryClient.ensureQueryData(sharedQueryOptions)`.
Native calls the same shared `useQuery(sharedQueryOptions)` directly from a
screen. The **query definition** (queryKey, queryFn, retry/staleTime policy
— the actual business logic) is 100% shared; only the *trigger* (router
lifecycle vs. component mount) differs per platform.

**Rejected initially, then reconciled:** fully independent per-platform
loader/query code (real duplication of fetch logic — the exact problem this
whole skill exists to prevent) — reconciled once it was clear the loader
function itself is routing plumbing (like navigation, which is already
app-specific), not business logic.

**Suspense:** adopted progressively, per screen, not mandated everywhere —
RN's Suspense-for-data-fetching maturity is real but less battle-tested than
web's; forcing it everywhere on day one is an avoidable risk for a skill
meant to be a durable default.

## 8. Coverage gate: 80%, layered enforcement

**Decision:** pre-push git hook (`nx affected -t test --coverage` +
`pytest --cov`) as fast local feedback (not pre-commit — full test+coverage
is too slow per-commit); **CI is the real gate** (git hooks are always
bypassable with `--no-verify`, so they can never be the *only* enforcement);
pipeline stage order ensures build/deploy never runs unless test+coverage
passed — coverage is never embedded literally inside the build command
itself (that would make the build tool test-aware and slow every local
build, including ones not headed to production).

**Threshold:** 80% lines+branches, repo-wide, from day one — achievable on
a fresh project with no legacy debt. **If this skill is ever used to
retrofit an existing codebase**, repo-wide 80% on day one is not realistic;
use diff/patch coverage instead for that case specifically. Repo-wide is the
default; diff-coverage is the documented exception, not the norm.

## 9. 1000-line file limit: hard lint error, with an editable exceptions list

**Decision:** ESLint's `max-lines` (error, 1000, skip blank/comments) for
TS/JS; a small `pre-commit`-framework Python script
(`scripts/check_file_length.py`) for the backend, since there's no standard
Python linter rule for this. Both wired into the same pre-push+CI
infrastructure as decision 8 — reuse, not a third enforcement path.

**Exceptions are explicitly user-addable** — a maintained glob/allowlist
(generated OpenAPI clients, Alembic version files, and anything else you
add), not a rigid rule. Line-count limits are a blunt instrument; a large
but legitimately simple generated file shouldn't force pointless manual
splitting. The tradeoff accepted: someone has to remember to add new
generated paths to the exemption list — it's not fully self-maintaining.

## 10. Test runners: Vitest (web + shared) / Jest scoped to native only

**The gap this closes:** RN's JS environment can't run on Vitest — Metro
needs Jest's `jest-expo` preset for native-module mocking. But Vitest is the
better fit for a Vite-based web app.

**Decision:** Vitest for `apps/web` **and** for `packages/core`/
`packages/hooks` (pure TS, no native-module dependency — they don't need
Jest's RN preset at all). Jest is scoped *only* to `apps/native`'s own
platform-specific code (screens, navigation glue). Coverage from both merges
(lcov) into one repo-wide 80% figure for decision 8's gate.

**Rejected:** Jest everywhere (avoids two configs, but slower/clunkier on
Vite-based web); Vitest everywhere including RN via community shims
(bleeding edge, no official RN preset equivalent, real native-module mocking
gaps).

**Ongoing risk:** two test runners is still two mental models — an agent
vibe-coding a test in `packages/hooks` may reflexively write `jest.fn()`
instead of `vi.fn()` since RN developers default to Jest muscle memory.
Mitigation: ESLint restricts `jest` globals to `apps/native` only, so using
Jest-style APIs outside it fails lint immediately rather than silently
passing with the wrong runner assumptions.

## 11. Backend folder structure: domain/feature-based vertical modules

**Decision:** `app/features/<domain>/{router.py, service.py, repository.py,
schemas.py, models.py, tests/}`, each feature self-contained with its own
`APIRouter` — FastAPI's own documented "bigger applications" pattern, not
invented here. Cross-cutting concerns (auth, db session, config) live in
`app/core/`, never duplicated per-domain.

**Rejected:** strict technical layering (`app/routers/`, `app/services/`,
etc., each mixing every domain) — guarantees repeated collisions with the
1000-line rule as features accumulate in shared layer files, forcing
arbitrary splits (`services_part2.py`) that don't reflect real boundaries.

**Why this one over the layered hybrid:** domain-first grouping is what
actually prevents the 1000-line rule from becoming a constant fire drill as
the project grows — new features get new folders, not bigger shared files.

## 12. Skill packaging: real templates, not prose

**Decision:** `SKILL.md` (the ruleset) + real boilerplate files under
`templates/` that the agent reads and writes into a new project with its
normal file tools — not a separate executable scaffold script, and not pure
documentation the agent regenerates from memory each time.

**Rejected:** prose-only SKILL.md (regenerating boilerplate from memory
each time is the exact failure mode — duplicated/drifted logic — this skill
exists to prevent); a wrapped executable script (adds script-maintenance and
cross-platform burden on Windows for a benefit — "runs identically every
time" — that copying static files via the agent's normal tools already
provides, since that *is* how a skill's templates are meant to be used).

**Known cost:** static template files are a frozen snapshot. Pinned package
versions and config syntax will drift out of date as Nx/Vite/FastAPI/etc.
evolve, and nothing auto-detects that — it's manual maintenance. Mitigated
by the "Last verified" date + pinned versions called out at the top of
`SKILL.md`, so staleness is visible rather than silent.

## 13. Ongoing memory: generated `CLAUDE.md` + enforced tooling together

**The gap:** this skill only fires when explicitly invoked, at setup time.
A fresh Claude Code session opened in that repo months later has no memory
of this conversation.

**Decision:** every scaffolded project gets a generated `CLAUDE.md`
(from `templates/root/CLAUDE.md.template`) with the condensed rule set,
since Claude Code auto-loads a repo's `CLAUDE.md` into every session — this
is what actually carries the rules forward, independent of anyone
re-invoking the skill. **Combined with**, not instead of, the enforced
tooling from decisions 8-10: `CLAUDE.md` carries the "why" so an agent
proposes correct code the *first* time (a lint/coverage failure alone only
tells it *after* it already got something wrong, and it won't know why the
architecture is shaped that way); the tooling is the hard backstop that
catches it if `CLAUDE.md` gets skimmed past or forgotten mid-task.

## 14. Cross-platform dependency version divergence

**The gap:** React Native legitimately pins tighter/older core-package
versions (React itself, polyfills) than web needs — this is normal, not a
bug, but it has to be handled deliberately or shared packages break one
platform or the other.

**Decision:**
- *Same package, different version* (e.g. React): `packages/core` and
  `packages/hooks` declare it as a `peerDependency` with a broad range
  (`"react": "^18.2.0 || ^19.0.0"`), never a pinned regular `dependency`.
  pnpm resolves that peer independently per consumer's own isolated
  dependency tree (its symlink-based `node_modules`, not npm-style flat
  hoisting) — `apps/web`'s and `apps/native`'s versions never collide. Each
  app keeps its own exact pin in its own `package.json`; nothing
  platform-sensitive is hoisted to the workspace root.
- *Not actually the same package* — genuinely platform-only libraries doing
  the same job (`@react-native-async-storage/async-storage` vs.
  `localStorage`/`idb-keyval`; native gesture/animation libs vs. web
  equivalents): shared logic never imports either directly. It defines a
  small interface; each app injects its own platform implementation
  (dependency inversion). This falls straight out of decision 3 — if shared
  logic seems to need a platform-only package, that's a sign the logic
  isn't actually platform-agnostic yet, not a reason to compromise the
  shared-package boundary.
- Enforcement: pnpm warns/errors on unmet peer-dependency ranges at
  `pnpm install` time automatically — this is the backstop, not something
  anyone has to remember to check by hand.
