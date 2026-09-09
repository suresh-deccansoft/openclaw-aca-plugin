/**
 * Jest is scoped to apps/native ONLY — decision #10. packages/core and
 * packages/hooks run under Vitest (apps/web/vite.config.ts); do not add a
 * jest config there, and do not add Vitest config here. Metro's runtime
 * needs jest-expo's native-module mocking, which Vitest doesn't provide an
 * equivalent for.
 */
module.exports = {
  preset: "jest-expo",
  transformIgnorePatterns: [
    "node_modules/(?!((jest-)?react-native|@react-native(-community)?)|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@unimodules/.*|unimodules|sentry-expo|native-base|react-native-svg)",
  ],
  collectCoverageFrom: ["**/*.{ts,tsx}", "!**/coverage/**", "!**/node_modules/**"],
  coverageThreshold: {
    // Repo-wide 80% gate — decision #8. Merges with the web/shared-package
    // Vitest coverage report in CI for the overall figure.
    global: {
      lines: 80,
      branches: 80,
      functions: 80,
      statements: 80,
    },
  },
};
