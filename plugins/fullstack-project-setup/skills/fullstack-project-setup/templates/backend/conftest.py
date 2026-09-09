import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import Base, async_session_factory, engine
from app.main import app


@pytest.fixture(autouse=True, scope="session")
async def _create_schema():
    """Uses the same async engine/Base as the app — see decision #5. Runs
    against DATABASE_URL (the CI postgres service container, or your local
    Azure Postgres Flexible Server dev instance)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def db_session() -> AsyncSession:
    async with async_session_factory() as session:
        yield session


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
