import { canCompleteTodo } from "@{{PROJECT_SLUG}}/core";
import { todosQueryOptions, useCreateTodo, useTodos } from "@{{PROJECT_SLUG}}/hooks";
import { useState } from "react";
import { queryClient } from "../query-client";

/**
 * Reference example for decision #7 (async data/loading state).
 *
 * `loader` is the ONLY web-specific piece here — a 1-3 line adapter that
 * pre-populates the shared query's cache before this route renders, giving
 * the Remix/React-Router "data ready before render" UX. It contains no
 * fetch logic of its own; `todosQueryOptions()` (from packages/hooks) is
 * the single source of truth for what/how to fetch, shared byte-for-byte
 * with apps/native/screens/TodosScreen.tsx, which calls the same
 * `useTodos()` directly from a screen instead of from a router loader.
 */
export function loader() {
  return queryClient.ensureQueryData(todosQueryOptions());
}

export function TodosPage() {
  // Reads from the cache the loader already populated — no loading flicker
  // on first render, same hook a native screen would call directly.
  const { data: todos = [], isLoading, error } = useTodos();
  const createTodo = useCreateTodo();
  const [title, setTitle] = useState("");

  if (error) {
    // `error` is an ApiError (packages/core) — same shape on both
    // platforms, only the presentation below is web-specific (HTML).
    return <p role="alert">Couldn't load todos: {error.message}</p>;
  }

  return (
    <main>
      <h1>Todos</h1>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          createTodo.mutate({ title });
          setTitle("");
        }}
      >
        <input value={title} onChange={(e) => setTitle(e.target.value)} />
        <button type="submit" disabled={createTodo.isPending}>
          Add
        </button>
      </form>
      {isLoading && <p>Loading…</p>}
      <ul>
        {todos.map((todo) => (
          <li key={todo.id}>
            {todo.title} {canCompleteTodo(todo) ? "" : "(done)"}
          </li>
        ))}
      </ul>
    </main>
  );
}
