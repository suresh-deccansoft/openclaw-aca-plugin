# Persistence options for OpenClaw on Azure Container Apps

The state dir (`/home/node/.openclaw`) holds conversation/session history. On Container Apps it is
**ephemeral** by default — it resets on every revision update, restart, or scale event — unless you
persist it. Three viable models, shaped by the SMB hard-link constraint (see
`azure-files-limitations.md`).

## A. Ephemeral (simplest, $0 extra)

Local disk only, no mount. The bot is fully functional; memory resets on every update/restart. Fine
for many single-bot use cases. Nothing to configure.

## B. Local + periodic SMB backup (the wizard's default) — `deploy-sync.sh`

Live state stays on **local disk** (so the Telegram spool's hard link works). A cheap **Standard SMB**
share is mounted at a *separate* path (`/mnt/state-backup`). The container's start command:

- **restores** state from the share on boot (excluding `telegram/` + `logs/`),
- **backs up** every 5 minutes via `cp -ru` (modification-time based — only changed files copy),
- does a **final sync on `SIGTERM`** (ACA sends it before stopping a revision), so planned
  updates/restarts lose nothing.

Trade-off: a *hard crash* can lose up to the last sync interval (≤ 5 min). No premium storage, no
VNet, no OpenClaw code changes. **Cost ≈ $0–1/month** (Standard SMB is pay-per-use, ~$0.06/GiB plus
tiny transaction costs for a few MB).

## C. Premium Azure Files NFS (real-time) — `deploy-nfs.sh`

NFS 4.1 supports hard links, so the share can back the state dir **directly** — true real-time
durability, no backup window to lose. Heavier and pricier:

- Premium `FileStorage` account, NFS 4.1 share (premium min 100 GiB → **~$15–16/mo**, or ~$6–9 if
  provisioned-v2 is available in the region).
- A **VNet-integrated** Container Apps environment (NFS has no TLS, so the share must be reached over
  a private network — service endpoint is free; a private endpoint adds ~$7/mo). You can't add a VNet
  to an existing environment, so this provisions a fresh one.

Choose this if losing even a few minutes of recent memory on a crash is unacceptable, or you want
clean real-time durability and accept the premium + networking cost.

## Summary

| Model | Memory survives update/restart | Crash loss window | Extra cost | Setup |
| --- | --- | --- | --- | --- |
| A. Ephemeral | ❌ | n/a | $0 | none |
| B. Local + SMB sync | ✅ (final sync on SIGTERM) | ≤ 5 min on hard crash | ~$0–1/mo | start-command + 1 Standard SMB mount |
| C. Premium NFS | ✅ real-time | none | ~$15–16/mo (+ VNet) | premium FileStorage + VNet env |
