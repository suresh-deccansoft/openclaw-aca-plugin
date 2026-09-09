# Module boundary tag scheme (Nx + eslint-plugin-boundaries)

Every project in the workspace is tagged in its `project.json`
(`"tags": [...]`). The root `.eslintrc.cjs` (`templates/root/.eslintrc.cjs`)
uses these tags to decide what's allowed to import what. This file documents
the scheme so it stays consistent as new packages/apps are added.

## Tags

- `type:app` — `apps/web`, `apps/native`. May depend on `type:logic`. May
  **not** depend on another `type:app` (web and native never import each
  other) and may not depend on `type:app-native-only`/`type:app-web-only`
  from the other platform.
- `type:logic` — `packages/core`, `packages/hooks`. May depend on other
  `type:logic` packages. May **not** depend on `type:app` — logic must never
  reach up into a platform's app code, or the boundary is meaningless.
- `type:config` — `packages/env`. May be depended on by anything. Has no
  outgoing dependency on `type:app` or `type:logic`.
- `scope:web` / `scope:native` — set alongside `type:app` on `apps/web` /
  `apps/native` respectively. Used to block a `type:logic` package from
  accidentally being platform-specific: nothing tagged `type:logic` may
  carry a `scope:web` or `scope:native` tag. If a shared package feels like
  it needs one, that's the signal from decision #14 (reference doc) that it
  needs a platform-injected interface instead, not a scope tag.

## Adding a new package

1. Decide which `type:*` tag applies using the definitions above — don't
   invent a new tag without updating this file.
2. Set it in the new package's `project.json`.
3. If it's a `type:logic` package, verify it has zero imports of anything
   platform-specific (no `react-native`, no DOM-only APIs) before merging —
   the lint rule catches direct cross-app imports, but it can't catch "this
   shared package only actually works on web" on its own.
