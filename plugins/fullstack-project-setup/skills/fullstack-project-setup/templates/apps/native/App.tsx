import { createApiClient } from "@{{PROJECT_SLUG}}/core";
import { loadEnv } from "@{{PROJECT_SLUG}}/env";
import { configureApiClient } from "@{{PROJECT_SLUG}}/hooks";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SafeAreaView } from "react-native";
import { TodosScreen } from "./screens/TodosScreen";

// Platform equivalent of apps/web/src/main.tsx — same shape, different
// prefix ("EXPO_PUBLIC_" vs "VITE_") and env source (process.env vs
// import.meta.env). See reference/architecture-decisions.md #4.
const env = loadEnv(process.env, "EXPO_PUBLIC_");
configureApiClient(createApiClient({ baseUrl: env.API_BASE_URL }));

const queryClient = new QueryClient();

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <SafeAreaView>
        <TodosScreen />
      </SafeAreaView>
    </QueryClientProvider>
  );
}
