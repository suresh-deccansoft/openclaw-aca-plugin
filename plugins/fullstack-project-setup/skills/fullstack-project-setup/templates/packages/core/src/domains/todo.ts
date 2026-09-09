import { z } from "zod";

/**
 * Reference example (decision #3): this is the ONLY place the "todo" shape
 * and its business rules are defined. Both apps/web and apps/native import
 * this — neither redefines it. Presentation (a checkbox on web, a
 * Switch/native gesture on RN) lives in each app; whether a todo CAN be
 * completed does not.
 */
export const todoSchema = z.object({
  id: z.string().uuid(),
  title: z.string().min(1).max(200),
  isCompleted: z.boolean(),
  createdAt: z.string().datetime(),
});

export type Todo = z.infer<typeof todoSchema>;

export const createTodoInputSchema = todoSchema.pick({ title: true });
export type CreateTodoInput = z.infer<typeof createTodoInputSchema>;

/**
 * Example business rule shared by both platforms — this is the kind of
 * logic that must NEVER be reimplemented per-app. If you find yourself
 * writing "can this todo be completed" inside a component, it belongs here
 * instead.
 */
export function canCompleteTodo(todo: Todo): boolean {
  return !todo.isCompleted && todo.title.trim().length > 0;
}
