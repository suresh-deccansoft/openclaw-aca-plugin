# Changelog

All notable changes to the `openclaw-azure` plugin are documented here.

## 1.0.0 — 2026-05-24

Initial release.

- `/openclaw-azure:deploy` guided wizard: preflight → collect inputs → BuildKit image build in ACR →
  persistence choice → deploy → verify.
- Two persistence strategies, both automated:
  - **local + periodic Standard-SMB backup** (`deploy-sync.sh`) — cheap, ≤5-min crash-loss window.
  - **premium Azure Files NFS + VNet** (`deploy-nfs.sh`) — real-time durability.
- `openclaw-azure-doctor` agent for diagnosing silent/broken deployments from the logs.
- Reference docs: Azure Files SMB hard-link limitation, persistence comparison, and the full
  gotchas list (BuildKit, IPv6 egress, `gateway.mode`, single-replica `getUpdates` conflict).
- Bundled scripts use `${CLAUDE_PLUGIN_ROOT}`, run `az` sequentially, and are idempotent
  (create-or-update).
