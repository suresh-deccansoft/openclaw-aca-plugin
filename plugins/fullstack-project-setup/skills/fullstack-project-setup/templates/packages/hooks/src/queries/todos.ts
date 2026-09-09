import { queryOptions, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createTodoInputSchema,
  todoSchema,
  type CreateTodoInput,
  type Todo,
} from "@{{PROJECT_SLUG}}/core";
import { z } from "zod";
import { getApiClient } from "../client";

/**
 * Reference example for decision #7 (async data/loading state).
 *
 * `todosQueryOptions()` is the ONE place "fetch todos" is defined — queryKey,
 * queryFn, and (if added later) retry/staleTime policy all live here.
 *
 *  - Native calls `useTodos()` directly from a screen component.
 *  - Web is allowed to trigger the SAME definition from a React Router
 *    loader as a thin adapter:
 *      export const loader = () => queryClient.ensureQueryData(todosQueryOptions())
 *    See apps/web/src/routes/todos.tsx.
 *
 * Neither platform re-implements the fetch logic — only the trigger
 * (router lifecycle vs. component mount) differs.
 */
export function todosQueryOptions() {
  return queryOptions({
    queryKey: ["todos"] as const,
    queryFn: async (): Promise<Todo[]> => {
      const data = await getApiClient().request<unknown[]>("/todos");
      return z.array(todoSchema).parse(data);
    },
  });
}

export function useTodos() {
  return useQuery(todosQueryOptions());
}

export function useCreateTodo() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (input: CreateTodoInput): Promise<Todo> => {
      const parsed = createTodoInputSchema.parse(input);
      const data = await getApiClient().request<unknown>("/todos", {
        method: "POST",
        body: JSON.stringify(parsed),
      });
      return todoSchema.parse(data);
    },
    // Cache invalidation is business logic too — shared here rather than
    // left for each screen/page to remember to do after a mutation.
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["todos"] });
    },
  });
}
