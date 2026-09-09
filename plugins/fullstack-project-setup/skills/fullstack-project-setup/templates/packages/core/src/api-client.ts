import { parseApiError } from "./errors";

export interface ApiClientConfig {
  baseUrl: string;
  getAuthToken?: () => string | undefined | Promise<string | undefined>;
}

export interface ApiClient {
  request<T>(path: string, init?: RequestInit): Promise<T>;
}

/**
 * Thin fetch wrapper shared by both apps — this is the ONLY place either
 * platform talks HTTP. Every non-2xx response is normalized into the same
 * ApiError (see ./errors.ts, RFC 7807). See
 * reference/architecture-decisions.md #6.
 *
 * Deliberately takes its config (baseUrl, auth token getter) as arguments
 * instead of reading env/storage itself — each app wires those from its own
 * platform mechanism (packages/env's loadEnv + whatever token storage that
 * platform uses) and passes them in. Keeps this file platform-agnostic, per
 * decision #14: shared logic never reaches for a platform-specific API
 * directly.
 */
export function createApiClient(config: ApiClientConfig): ApiClient {
  return {
    async request<T>(path: string, init: RequestInit = {}): Promise<T> {
      const token = await config.getAuthToken?.();
      const response = await fetch(`${config.baseUrl}${path}`, {
        ...init,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...init.headers,
        },
      });

      if (!response.ok) {
        throw await parseApiError(response);
      }

      if (response.status === 204) {
        return undefined as T;
      }
      return (await response.json()) as T;
    },
  };
}
