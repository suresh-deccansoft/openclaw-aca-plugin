# openclaw-azure

Deploy [OpenClaw](https://github.com/openclaw/openclaw) to **Azure Container Apps** with a guided,
correct workflow. Telegram via long polling, LiteLLM as the model backend, and a persistence wizard
that avoids the Azure Files SMB hard-link trap.

## Usage

```shell
/openclaw-azure:deploy
```

Or just ask Claude to "deploy OpenClaw to Azure" — the `Deploy OpenClaw to Azure` skill triggers
automatically.

The wizard walks through:

1. **Preflight** — checks `az` login, Docker, and ACR reachability.
2. **Inputs** — ACR, resource group, region, LiteLLM endpoint/key/model, Telegram bot token + allowed user.
3. **Build** — builds the OpenClaw image in ACR with **BuildKit** (required by its Dockerfile).
4. **Persistence choice** — cheap **local + periodic SMB backup**, or premium **NFS + VNet** (real-time).
5. **Deploy** — creates/updates the Container App (no ingress, single replica, IPv4 forced, `gateway.mode:local`).
6. **Verify** — tails logs and confirms the gateway is ready and Telegram is polling.

## Troubleshooting

If the bot is silent or misbehaving, ask Claude to "diagnose my OpenClaw Azure deployment" to invoke
the **`openclaw-azure-doctor`** agent. It maps symptoms to causes:

| Symptom | Likely cause |
|---|---|
| Bot receives messages but never replies | Azure Files **SMB** mounted at state dir → spool `link()` `ENOTSUP` |
| Replies take ~10–15s | IPv6 egress to Telegram (force IPv4) |
| Image build fails on `--mount` | classic builder; needs **BuildKit** |
| Gateway won't start | missing `gateway.mode: local` |

## Requirements

- Azure CLI (`az`) logged in, with the `containerapp` extension.
- Docker (only if you choose to build locally; the default builds in ACR).
- An Azure Container Registry.
- A LiteLLM (OpenAI-compatible) endpoint + key, and a Telegram bot token from @BotFather.

## Reference docs

- `skills/deploy-openclaw/references/azure-files-limitations.md`
- `skills/deploy-openclaw/references/persistence-options.md`
- `skills/deploy-openclaw/references/gotchas.md`

## License

MIT.
