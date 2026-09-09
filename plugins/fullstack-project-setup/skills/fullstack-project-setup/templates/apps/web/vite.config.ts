import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [react()],
  test: {
    // Vitest for web + shared packages — decision #10. Jest is scoped to
    // apps/native only; do not add a jest config here.
    environment: "jsdom",
    globals: true,
    coverage: {
      provider: "v8",
      // Repo-wide 80% gate — decision #8. CI is the real enforcement point
      // (see .github/workflows/ci.yml); this makes local `pnpm test` fail
      // the same way so it's never a surprise at push time.
      thresholds: {
        lines: 80,
        branches: 80,
        functions: 80,
        statements: 80,
      },
    },
  },
});
