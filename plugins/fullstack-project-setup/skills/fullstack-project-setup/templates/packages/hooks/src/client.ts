import type { ApiClient } from "@{{PROJECT_SLUG}}/core";

/**
 * Module-level singleton, configured once at app startup — see
 * apps/web/src/main.tsx and apps/native/App.tsx. Deliberately not a React
 * Context Provider: this package holds zero JSX (decision #3), and a
 * singleton is enough since there's exactly one API client per running app,
 * on both platforms.
 */
let client: ApiClient | undefined;

export function configureApiClient(instance: ApiClient): void {
  client = instance;
}

export function getApiClient(): ApiClient {
  if (!client) {
    throw new Error(
      "getApiClient() called before configureApiClient(). Call " +
        "configureApiClient() once at app startup — see apps/web/src/main.tsx " +
        "or apps/native/App.tsx for the pattern."
    );
  }
  return client;
}
