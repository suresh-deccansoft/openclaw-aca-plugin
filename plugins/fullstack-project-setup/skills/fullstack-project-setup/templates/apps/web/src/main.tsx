import { createApiClient } from "@{{PROJECT_SLUG}}/core";
import { loadEnv } from "@{{PROJECT_SLUG}}/env";
import { configureApiClient } from "@{{PROJECT_SLUG}}/hooks";
import { QueryClientProvider } from "@tanstack/react-query";
import React from "react";
import ReactDOM from "react-dom/client";
import { RouterProvider } from "react-router-dom";
import { queryClient } from "./query-client";
import { router } from "./router";

// The only place this app touches env directly and constructs its own
// ApiClient — see reference/architecture-decisions.md #4 and #6.
// apps/native/App.tsx does the platform equivalent of exactly this, with
// its own prefix ("EXPO_PUBLIC_") and its own auth-token storage mechanism.
const env = loadEnv(import.meta.env, "VITE_");
configureApiClient(createApiClient({ baseUrl: env.API_BASE_URL }));

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </React.StrictMode>
);
