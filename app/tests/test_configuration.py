import json

import pytest

from app import app as app_module


def test_missing_secret_configuration_is_explicit(monkeypatch):
    monkeypatch.delenv("DB_SECRET_ARN", raising=False)
    monkeypatch.delenv("DB_SECRET_NAME", raising=False)
    monkeypatch.delenv("SECRET_NAME", raising=False)
    with pytest.raises(app_module.ConfigurationError, match="DB_SECRET_ARN"):
        app_module._secret_name()


def test_invalid_secret_shape_is_rejected():
    with pytest.raises(app_module.ConfigurationError, match="missing required"):
        app_module._normalise_secret({"host": "db", "username": "user"})


def test_secret_provider_rejects_invalid_json(monkeypatch):
    monkeypatch.setenv("AWS_REGION", "us-east-1")
    monkeypatch.setenv("DB_SECRET_ARN", "arn:aws:secretsmanager:us-east-1:123456789012:secret:test")
    class InvalidSecret:
        def get_secret_value(self, SecretId):
            return {"SecretString": json.dumps(["not", "an", "object"])}

    with pytest.raises(app_module.ConfigurationError, match="JSON object"):
        app_module.SecretProvider(client=InvalidSecret()).get()
