# Azure Files limitations with OpenClaw (read this before mounting a share)

The single most important thing to know when persisting OpenClaw state on Azure: **do not mount an
Azure Files SMB share at the state directory (`/home/node/.openclaw`).** It looks like it works, then
silently breaks the bot.

## Why SMB breaks OpenClaw

OpenClaw's Telegram channel uses an **isolated ingress spool**: each inbound update is written to a
file, then "claimed" for processing by creating a **hard link** (`link(2)`) — an atomic, crash-safe
handoff so exactly one worker processes each update.

**SMB / CIFS file shares do not support hard links.** The `link()` call returns `ENOTSUP`. You see a
tight retry loop in the logs and the update is never processed:

```
[telegram] [diag] spooled update <id> claim failed; keeping for retry:
ENOTSUP: operation not supported on socket,
link '.../telegram/ingress-spool-default/<id>.json' -> '....claim'
```

The insidious part: **the gateway starts fine, config loads fine, most state writes fine** — only
message *processing* is broken. The bot receives your messages (you'll see `Inbound message ...` in
the logs) but never replies, with no fatal error. It's easy to misdiagnose as a model/network issue.

This is not configurable away: OpenClaw's `isolatedIngress.enabled` defaults to `true` and is not
exposed as a config/env knob, so the spool (and its hard link) is always in the path.

## What SMB *is* fine for

SMB rejects `link()`, but ordinary file operations (create, write, rename, `cp`) work fine. So SMB is
a perfectly good **backup target** as long as you only ever copy *into* it and never create hard
links there. That is exactly what the "local + periodic SMB sync" persistence model does: the live
state (with the hard-link spool) stays on **local disk**, and a background loop `cp`s the durable
parts (sessions, plugin-state, etc.) to the SMB share — explicitly **excluding** the `telegram/`
spool directory so no `link()` ever touches SMB.

## The fix for a real-time mount: NFS

Azure Files also offers **NFS 4.1** shares (on premium `FileStorage` accounts). NFS is a full POSIX
filesystem and **supports hard links**, so the Telegram spool's `link()` succeeds and you can mount
the share directly at `/home/node/.openclaw` for real-time durability.

The cost: NFS requires a **premium** storage account (~$15/mo minimum at the 100 GiB provisioned
floor) and, because NFS has **no encryption in transit**, a **VNet-integrated** Container Apps
environment so the share is only reachable over a private network. See `persistence-options.md`.

## Quick reference

| Operation OpenClaw needs | SMB Azure Files | NFS Azure Files | Local disk |
| --- | --- | --- | --- |
| Read/write/rename files | ✅ | ✅ | ✅ |
| Hard links (`link()`) for the Telegram spool | ❌ `ENOTSUP` | ✅ | ✅ |
| Safe as a live state-dir mount | ❌ | ✅ | ✅ (ephemeral) |
| Safe as a copy-only backup target | ✅ | ✅ | n/a |
