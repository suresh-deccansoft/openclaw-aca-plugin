from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Backend's OWN .env — separate from the root shared .env consumed by the
    frontends. See reference/architecture-decisions.md #4: real secrets
    (DATABASE_URL with credentials, etc.) live here, NEVER in the root
    shared .env, because that file ends up inside the React Native bundle,
    which is fully decompilable.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/app_dev"
    cors_origins: list[str] = ["http://localhost:5173"]

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()
