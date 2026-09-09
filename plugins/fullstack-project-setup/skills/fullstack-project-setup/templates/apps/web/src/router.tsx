import { createBrowserRouter } from "react-router-dom";
import { loader as todosLoader, TodosPage } from "./routes/todos";

export const router = createBrowserRouter([
  {
    path: "/todos",
    element: <TodosPage />,
    loader: todosLoader,
  },
]);
