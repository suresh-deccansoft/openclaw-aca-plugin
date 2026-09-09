from sqlalchemy.ext.asyncio import AsyncSession

from app.features.todos import repository
from app.features.todos.models import Todo
from app.features.todos.schemas import TodoCreate


async def list_todos(session: AsyncSession) -> list[Todo]:
    return await repository.list_todos(session)


async def create_todo(session: AsyncSession, payload: TodoCreate) -> Todo:
    # Business-rule validation beyond simple field constraints belongs here,
    # not in the router. Raise ValidationAppError (app.core.errors) for
    # anything that should surface as a field-level error — see that
    # module's docstring for the shape.
    return await repository.create_todo(session, title=payload.title)
