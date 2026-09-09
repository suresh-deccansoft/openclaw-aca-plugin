import { z } from "zod";

/**
 * See reference/architecture-decisions.md #4. The shared .env duplicates
 * every value under both bundler-required prefixes (VITE_* / EXPO_PUBLIC_*).
 * This schema strips whichever prefix the calling app used and validates
 * the result once, so web and native consume the exact same typed `Env`
 * shape downstream — the prefix difference never leaks past this file.
 *
 * When you add a new shared config value: add it here, add both prefixed
 * keys to .env.example (root), and confirm scripts/check-public-env.js
 * still passes (it will, as long as both keys contain "_PUBLIC_").
 */
const rawEnvSchema = z.object({
  API_BASE_URL: z.string().url(),
  APP_ENV: z.enum(["development", "staging", "production"]),
});

export type Env = z.infer<typeof rawEnvSchema>;

/**
 * @param source The platform's raw env object — `import.meta.env` on web
 *   (Vite), `process.env` on native (Expo).
 * @param prefix The prefix to strip before validating — "VITE_" or
 *   "EXPO_PUBLIC_".
 */
export function loadEnv(
  source: Record<string, string | undefined>,
  prefix: string
): Env {
  const stripped: Record<string, string | undefined> = {};
  for (const [key, value] of Object.entries(source)) {
    if (key.startsWith(prefix)) {
      stripped[key.slice(prefix.length)] = value;
    }
  }

  const result = rawEnvSchema.safeParse(stripped);
  if (!result.success) {
    const issues = result.error.issues
      .map((issue) => `  - ${issue.path.join(".")}: ${issue.message}`)
      .join("\n");
    throw new Error(
      `Invalid environment configuration (prefix "${prefix}"):\n${issues}\n` +
        `Check .env against .env.example at the repo root.`
    );
  }
  return result.data;
}
