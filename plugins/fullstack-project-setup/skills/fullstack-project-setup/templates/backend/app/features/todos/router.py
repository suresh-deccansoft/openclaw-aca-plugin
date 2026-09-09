from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.features.todos import service
from app.features.todos.schemas import TodoCreate, TodoRead

router = APIRouter(prefix="/todos", tags=["todos"])


@router.get("", response_model=list[TodoRead])
async def list_todos(session: AsyncSession = Depends(get_db)) -> list[TodoRead]:
    todos = await service.list_todos(session)
    return [TodoRead.model_validate(t) for t in todos]


@router.post("", response_model=TodoRead, status_code=status.HTTP_201_CREATED)
async def create_todo(payload: TodoCreate, session: AsyncSession = Depends(get_db)) -> TodoRead:
    todo = await service.create_todo(session, payload)
    return TodoRead.model_validate(todo)
