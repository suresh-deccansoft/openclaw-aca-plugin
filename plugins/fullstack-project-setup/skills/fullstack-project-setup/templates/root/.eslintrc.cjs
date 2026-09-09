/**
 * Root ESLint config. See templates/eslint/module-boundaries.md for the tag
 * scheme this enforces, and reference/architecture-decisions.md #1, #9, #10
 * for why these rules exist.
 *
 * Add file-length or boundary exceptions ONLY in the `overrides` array below
 * — never disable these rules inline in application code.
 */
module.exports = {
  root: true,
  ignorePatterns: ["**/dist", "**/node_modules", "**/.expo", "**/coverage"],
  plugins: ["boundaries"],
  settings: {
    "boundaries/elements": [
      { type: "app", pattern: "apps/*" },
      { type: "logic", pattern: "packages/core/*" },
      { type: "logic", pattern: "packages/hooks/*" },
      { type: "config", pattern: "packages/env/*" },
    ],
  },
  overrides: [
    // --- Everything: the 1000-line hard limit ---
    {
      files: ["**/*.{ts,tsx,js,jsx}"],
      rules: {
        "max-lines": [
          "error",
          { max: 1000, skipBlankLines: true, skipComments: true },
        ],
      },
    },

    // --- Line-length EXCEPTIONS — add new globs here, deliberately ---
    {
      files: [
        "**/*.generated.ts",
        "**/generated/**",
        "**/*.d.ts",
        "packages/core/src/api-types.ts", // openapi-typescript output
      ],
      rules: {
        "max-lines": "off",
      },
    },

    // --- Module boundaries: RN = UI only, React = HTML only, logic is shared ---
    {
      files: ["**/*.{ts,tsx}"],
      rules: {
        "boundaries/element-types": [
          "error",
          {
            default: "disallow",
            rules: [
              { from: "app", allow: ["logic", "config"] },
              { from: "logic", allow: ["logic", "config"] },
              { from: "config", allow: [] },
            ],
          },
        ],
      },
    },

    // --- Test runner split: Vitest in packages/*, Jest ONLY in apps/native ---
    // (decision #10 — this is what stops an agent reflexively writing
    // jest.fn() in shared logic out of RN muscle memory.)
    {
      files: ["packages/**/*.{test,spec}.{ts,tsx}", "apps/web/**/*.{test,spec}.{ts,tsx}"],
      env: { jest: false },
      globals: { vi: "readonly", describe: "readonly", it: "readonly", expect: "readonly" },
      rules: {
        "no-restricted-globals": ["error", "jest"],
      },
    },
    {
      files: ["apps/native/**/*.{test,spec}.{ts,tsx}"],
      env: { jest: true },
    },
  ],
};
