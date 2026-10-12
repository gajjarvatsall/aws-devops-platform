import json

import pytest

from app import app as app_module


class FakeSecrets:
    def get_secret_value(self, SecretId):
        return {"SecretString": json.dumps({
            "host": "localhost", "username": "demo", "password": "secret",
            "dbname": "demo", "port": 3306,
        })}


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("AWS_REGION", "us-east-1")
    monkeypatch.setenv("DB_SECRET_NAME", "cloudops/demo")
    provider = app_module.SecretProvider(client=FakeSecrets())
    application = app_module.create_app(provider)
    application.config.update(TESTING=True)
    return application.test_client()
