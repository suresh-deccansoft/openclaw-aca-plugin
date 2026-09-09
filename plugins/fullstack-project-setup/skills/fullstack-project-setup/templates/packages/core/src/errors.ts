/**
 * RFC 7807 Problem Details, normalized. See
 * reference/architecture-decisions.md #6.
 *
 * The `errors` field is a project-defined extension for field-level
 * validation (not part of RFC 7807 itself) — this is the ONE shape both
 * backend/app/core/errors.py and every frontend form use for it. Don't
 * invent a second field-error shape elsewhere.
 */
export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  errors?: { field: string; message: string }[];
  [extension: string]: unknown;
}

export class ApiError extends Error {
  readonly type: string;
  readonly status: number;
  readonly detail?: string;
  readonly instance?: string;
  readonly fieldErrors: { field: string; message: string }[];

  constructor(problem: ProblemDetails) {
    super(problem.title);
    this.name = "ApiError";
    this.type = problem.type;
    this.status = problem.status;
    this.detail = problem.detail;
    this.instance = problem.instance;
    this.fieldErrors = problem.errors ?? [];
  }

  /** True for the field-validation shape — forms should check this first. */
  get isValidationError(): boolean {
    return this.fieldErrors.length > 0;
  }
}

/**
 * Every non-2xx response from the shared api-client goes through this.
 * Callers (web AND native, via packages/hooks) only ever handle `ApiError`
 * — never a raw fetch Response, never a platform-specific error shape.
 */
export async function parseApiError(response: Response): Promise<ApiError> {
  try {
    const body = (await response.json()) as ProblemDetails;
    return new ApiError(body);
  } catch {
    // Backend didn't return a Problem Details body — a proxy error page, a
    // network-level failure, etc. Normalize to the same shape anyway so
    // callers never need a second error type to handle.
    return new ApiError({
      type: "about:blank",
      title: response.statusText || "Unknown error",
      status: response.status,
    });
  }
}
