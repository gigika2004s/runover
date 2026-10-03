import os

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "test-only-secret-key-that-is-long-enough")

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.main import app

test_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def clean_database():
    Base.metadata.drop_all(bind=test_engine)
    Base.metadata.create_all(bind=test_engine)
    yield


@pytest.fixture
def client():
    # Do not enter the application lifespan: its local demo seed uses the
    # development engine, while each request is redirected to test_engine.
    yield TestClient(app)


@pytest.fixture
def db_session():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def registered_user(client):
    response = client.post("/auth/register", json={
        "full_name": "Test Runner",
        "username": "testrunner",
        "email": "runner@example.com",
        "password": "original123",
        "accept_terms": True,
    })
    assert response.status_code == 201
    return {"token": response.json()["access_token"], "email": "runner@example.com"}
