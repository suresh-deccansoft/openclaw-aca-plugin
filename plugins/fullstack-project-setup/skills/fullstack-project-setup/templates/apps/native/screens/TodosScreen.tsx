import { canCompleteTodo } from "@{{PROJECT_SLUG}}/core";
import { useCreateTodo, useTodos } from "@{{PROJECT_SLUG}}/hooks";
import { useState } from "react";
import { Button, FlatList, Text, TextInput, View } from "react-native";

/**
 * Reference example for decision #7. Same `useTodos()` / `useCreateTodo()`
 * hooks as apps/web/src/routes/todos.tsx, called directly from a screen —
 * React Navigation has no route-loader equivalent to React Router's, so
 * there's no adapter here, just the shared hook. Presentation is native UI
 * (FlatList, TextInput) instead of HTML; the data/business logic is
 * byte-for-byte the same code as web.
 */
export function TodosScreen() {
  const { data: todos = [], isLoading, error } = useTodos();
  const createTodo = useCreateTodo();
  const [title, setTitle] = useState("");

  if (error) {
    // Same ApiError shape as web — only the presentation differs.
    return <Text accessibilityRole="alert">Couldn't load todos: {error.message}</Text>;
  }

  return (
    <View>
      <TextInput value={title} onChangeText={setTitle} placeholder="New todo" />
      <Button
        title="Add"
        disabled={createTodo.isPending}
        onPress={() => {
          createTodo.mutate({ title });
          setTitle("");
        }}
      />
      {isLoading && <Text>Loading…</Text>}
      <FlatList
        data={todos}
        keyExtractor={(todo) => todo.id}
        renderItem={({ item }) => (
          <Text>
            {item.title} {canCompleteTodo(item) ? "" : "(done)"}
          </Text>
        )}
      />
    </View>
  );
}
