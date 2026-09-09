#!/usr/bin/env node
/**
 * Pre-commit guard for decision #4 (reference/architecture-decisions.md):
 * the shared .env file feeds the React Native bundle, which is fully
 * decompilable — so nothing in it may be a real secret. This script fails
 * the commit if a key in .env / .env.example doesn't look like a public
 * client config value.
 *
 * Add to ALLOWLIST below ONLY for keys you are certain are safe to ship
 * inside a public mobile app bundle. Don't add a key here to silence this
 * check without actually checking that.
 */
const fs = require("fs");
const path = require("path");

const ALLOWLIST = new Set([
  // Non-secret keys that don't fit the *_PUBLIC_* naming pattern but are
  // genuinely safe to be public. Keep this list short and deliberate.
]);

const PUBLIC_PATTERN = /_PUBLIC_/;
const FILES = [".env", ".env.example"];

let failed = false;

for (const file of FILES) {
  const filePath = path.join(process.cwd(), file);
  if (!fs.existsSync(filePath)) continue;

  const lines = fs.readFileSync(filePath, "utf8").split("\n");
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();

    if (!PUBLIC_PATTERN.test(key) && !ALLOWLIST.has(key)) {
      console.error(
        `[check-public-env] "${key}" in ${file} is not *_PUBLIC_* and not ` +
          `in the ALLOWLIST in scripts/check-public-env.js.\n` +
          `  This file ships inside the React Native bundle, which is ` +
          `fully decompilable. If "${key}" is a real secret, move it to ` +
          `backend/.env or Azure Key Vault instead. If it's genuinely safe ` +
          `to be public, add it to ALLOWLIST deliberately.`
      );
      failed = true;
    }
  }
}

process.exit(failed ? 1 : 0);
