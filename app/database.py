"""SQLAlchemy engine/session wiring.

A single module owns engine creation so that both the application and the
test suite construct sessions the same way. Tests override `DATABASE_URL`
(see tests/conftest.py) rather than monkeypatching internals here.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import get_settings

settings = get_settings()

# `check_same_thread` is only needed for SQLite; it's a no-op/ignored for
# Postgres so it's safe to always pass connect_args this way when sqlite.
connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}

engine = create_engine(settings.database_url, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI dependency that yields a request-scoped DB session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
