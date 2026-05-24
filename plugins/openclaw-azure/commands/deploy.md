---
description: Deploy OpenClaw to Azure Container Apps (guided wizard)
argument-hint: "[optional notes, e.g. resource group or region]"
allowed-tools: ["Read", "Bash", "AskUserQuestion", "TaskCreate", "TaskUpdate", "TaskList", "Skill"]
---

Run the **Deploy OpenClaw to Azure** workflow defined in the `deploy-openclaw` skill of this
plugin (`${CLAUDE_PLUGIN_ROOT}/skills/deploy-openclaw/SKILL.md`). Follow that skill's phases exactly:
preflight → collect inputs → build image (BuildKit) → choose persistence → deploy → verify.

If the user provided any notes after the command, treat them as hints for inputs (e.g. resource
group, region): $ARGUMENTS
