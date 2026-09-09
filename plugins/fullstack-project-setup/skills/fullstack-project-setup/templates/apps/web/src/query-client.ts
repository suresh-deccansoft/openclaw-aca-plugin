import { QueryClient } from "@tanstack/react-query";

// Separate file from main.tsx so route loaders (src/routes/*) can import it
// without a circular import back through main.tsx → router.tsx → main.tsx.
export const queryClient = new QueryClient();
