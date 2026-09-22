import os

# Must be set BEFORE importing the app, since settings are read at import time.
os.environ["URLSHORT_DATABASE_URL"] = "sqlite:///:memory:"
os.environ["URLSHORT_BASE_URL"] = "http://testserver"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

# A single shared in-memory SQLite connection (StaticPool) so all sessions
# within a test see the same schema/data, and each test function gets a
# fresh database via the `client` fixture below.
_engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
_TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=_engine)


def _override_get_db():
    db = _TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = _override_get_db


@pytest.fixture()
def client():
    Base.metadata.create_all(bind=_engine)
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(bind=_engine)
