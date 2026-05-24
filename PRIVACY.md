# Privacy Policy — `openclaw-azure` Claude Code plugin

_Last updated: 2026-05-24_

## Summary

The `openclaw-azure` plugin **does not collect, store, transmit, or share any personal data** with
its authors (Deccansoft) or any third party. It contains no telemetry, analytics, tracking, or
"phone-home" behavior. Everything it does runs locally inside your own Claude Code session and against
**your own** cloud accounts and services.

## What the plugin does

`openclaw-azure` is a deployment helper. When you run it, it executes commands on **your machine**
(for example `az`, `git`, `curl`, and optionally `docker`) to build and deploy an
[OpenClaw](https://github.com/openclaw/openclaw) container to **your** Azure subscription.

## Information you provide

To perform a deployment you may provide values such as your Azure resource names, a LiteLLM endpoint
URL and API key, and a Telegram bot token and allowed user ID. These values:

- are used **only** to carry out the deployment you requested;
- are sent **only** to the services they belong to — your Azure subscription (where they are stored as
  Azure Container App **secrets** under your control), your own LiteLLM endpoint, and the official
  Telegram Bot API (`api.telegram.org`) for validation;
- are **never** transmitted to Deccansoft, the plugin authors, or any other third party;
- are **not** written to the plugin's files or committed to any repository by the plugin.

The plugin authors have **no access** to your credentials, your Azure resources, your bot, or your
conversations.

## Network connections

The plugin's scripts may connect to: Microsoft Azure (`management.azure.com`, your Azure Container
Registry, and related Azure endpoints), your configured LiteLLM endpoint, and the Telegram Bot API —
all using credentials **you** supply, and only to perform the deployment. The plugin makes no other
network calls.

## Data retention

The plugin retains nothing. Any state created by a deployment (configuration, conversation history)
lives entirely within **your** Azure resources and is governed by your own Azure data settings and the
privacy practices of the services you connect (LiteLLM provider, Telegram). Deletion of your Azure
resources removes that data.

## Third-party services

Using this plugin connects you to third-party services under their own terms and privacy policies,
including [Microsoft Azure](https://privacy.microsoft.com/), [Telegram](https://telegram.org/privacy),
and whichever model provider your LiteLLM endpoint is configured to use. Review their policies
separately.

## Changes

Updates to this policy will be published in this file in the plugin's public repository.

## Contact

Questions about this policy: **aiteam@deccansoft.net**
