"""Application configuration, loaded from environment variables.

Keeping configuration in one place (instead of scattering os.getenv()
calls through the codebase) makes it obvious to a new engineer what
can be tuned and how, and makes it trivial to override in tests.
"""
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # SQLAlchemy connection string. Defaults to a local SQLite file so the
    # app runs with zero external dependencies out of the box; docker-compose
    # overrides this to point at the Postgres service (see docker-compose.yml).
    database_url: str = "sqlite:///./urlshort.db"

    # Base URL used to build the `short_url` returned to clients, e.g.
    # "https://sho.rt". Defaults to localhost for local/dev use.
    base_url: str = "http://localhost:8000"

    # Length of the randomly generated short code when the caller does not
    # supply a custom alias.
    code_length: int = 7

    model_config = SettingsConfigDict(env_file=".env", env_prefix="URLSHORT_")


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton, dependency-injected into request handlers."""
    return Settings()
