from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from oracle_app.api import create_app


@pytest.fixture
def app():
    return create_app()


@pytest.fixture
def client(app):
    with TestClient(app) as test_client:
        yield test_client
