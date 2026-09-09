from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_settings

settings = get_settings()

# Async engine + asyncpg — decision #5. This same engine is what Alembic's
# async template (alembic/env.py) drives migrations through; there is
# deliberately no second, sync engine to keep in sync.
engine = create_async_engine(settings.database_url, echo=not settings.is_production)

async_session_factory = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    """
    Every model inherits from this. HARD RULE (decision #5): never rely on a
    relationship's implicit lazy-load here — it raises MissingGreenlet at
    runtime in async context, not at write time. Always pass an explicit
    `lazy="selectin"` on the relationship, or eager-load with
    `.options(selectinload(...))` at the query site. See
    app/features/todos/repository.py for the pattern.
    """


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency — see app/features/todos/router.py for usage."""
    async with async_session_factory() as session:
        yield session
