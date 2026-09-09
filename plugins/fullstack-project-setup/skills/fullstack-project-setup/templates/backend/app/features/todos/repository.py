import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.todos.models import Todo

# This feature's model has no relationships to eager-load yet, so there's no
# selectinload/joinedload call here — but the rule (decision #5) still
# applies the moment one is added: never rely on implicit lazy-loading in
# async context.


async def list_todos(session: AsyncSession) -> list[Todo]:
    result = await session.execute(select(Todo).order_by(Todo.created_at.desc()))
    return list(result.scalars().all())


async def create_todo(session: AsyncSession, title: str) -> Todo:
    todo = Todo(title=title)
    session.add(todo)
    await session.commit()
    await session.refresh(todo)
    return todo


async def get_todo(session: AsyncSession, todo_id: uuid.UUID) -> Todo | None:
    return await session.get(Todo, todo_id)
