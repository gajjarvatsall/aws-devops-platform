"""CloudOps Demo HTTP service."""

from __future__ import annotations

import json
import logging
import os
import threading
import time
from typing import Any

import boto3
import pymysql
from botocore.exceptions import BotoCoreError, ClientError
from flask import Flask, Response, jsonify


class ConfigurationError(RuntimeError):
    """Raised when the application cannot be configured safely."""


def _int_env(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


def _region() -> str:
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
    if not region:
        raise ConfigurationError("AWS_REGION is required")
    return region


def _secret_name() -> str:
    name = os.getenv("DB_SECRET_ARN") or os.getenv("DB_SECRET_NAME") or os.getenv("SECRET_NAME")
    if not name:
        raise ConfigurationError("DB_SECRET_ARN is required")
    return name


def _normalise_secret(value: dict[str, Any]) -> dict[str, Any]:
    aliases = {"dbname": "database", "db_name": "database", "db": "database", "user": "username"}
    result = {aliases.get(key.lower(), key.lower()): item for key, item in value.items()}
    required = ("host", "username", "password", "database")
    if any(not result.get(key) for key in required):
        raise ConfigurationError("database secret is missing required fields")
    try:
        result["port"] = int(result.get("port", 3306))
    except (TypeError, ValueError) as exc:
        raise ConfigurationError("database secret contains an invalid port") from exc
    return result


class SecretProvider:
    """Fetch and cache the database secret for a short, documented TTL."""

    def __init__(self, client: Any = None, ttl: int | None = None) -> None:
        self._client = client
        self._ttl = ttl if ttl is not None else _int_env("SECRET_CACHE_TTL", 300)
        self._cached: dict[str, Any] | None = None
        self._expires_at = 0.0
        self._lock = threading.Lock()

    def get(self) -> dict[str, Any]:
        if self._cached is not None and time.monotonic() < self._expires_at:
            return self._cached
        with self._lock:
            if self._cached is not None and time.monotonic() < self._expires_at:
                return self._cached
            client = self._client or boto3.client("secretsmanager", region_name=_region())
            try:
                response = client.get_secret_value(SecretId=_secret_name())
                raw = response.get("SecretString")
                if raw is None and response.get("SecretBinary") is not None:
                    raw = response["SecretBinary"].decode("utf-8")
                value = json.loads(raw or "")
            except (BotoCoreError, ClientError, TypeError, ValueError, UnicodeDecodeError) as exc:
                raise ConfigurationError("database secret could not be loaded") from exc
            if not isinstance(value, dict):
                raise ConfigurationError("database secret must contain a JSON object")
            self._cached = _normalise_secret(value)
            self._expires_at = time.monotonic() + max(0, self._ttl)
            return self._cached


def _database_check(secret_provider: SecretProvider) -> None:
    secret = secret_provider.get()
    connection = pymysql.connect(
        host=secret["host"],
        user=secret["username"],
        password=secret["password"],
        database=secret["database"],
        port=secret["port"],
        connect_timeout=_int_env("DB_CONNECT_TIMEOUT", 3),
        read_timeout=_int_env("DB_READ_TIMEOUT", 3),
        write_timeout=_int_env("DB_WRITE_TIMEOUT", 3),
        cursorclass=pymysql.cursors.DictCursor,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    finally:
        connection.close()


def create_app(secret_provider: SecretProvider | None = None) -> Flask:
    application = Flask(__name__)
    provider = secret_provider or SecretProvider()
    application.config["SECRET_PROVIDER"] = provider

    @application.get("/")
    def index() -> Response:
        environment = os.getenv("APP_ENVIRONMENT") or os.getenv("APP_ENV", "production")
        version = os.getenv("APP_VERSION", "0.1.0")
        body = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>CloudOps Demo</title>
<style>body{{font-family:system-ui;max-width:760px;margin:4rem auto;padding:0 1rem;background:#f5f7fb;color:#172033}}
main{{background:white;border-radius:12px;padding:2rem;box-shadow:0 5px 24px #17203320}}
a{{color:#1261a0;margin-right:1rem}}</style></head>
<body><main><h1>CloudOps Demo</h1><p>Production-style AWS platform reference application.</p>
<dl><dt>Version</dt><dd>{version}</dd><dt>Environment</dt><dd>{environment}</dd>
<dt>Status</dt><dd>Running</dd></dl>
<p><a href="/health">Health</a><a href="/ready">Readiness</a><a href="/api/status">API status</a></p>
</main></body></html>"""
        return Response(body, mimetype="text/html")

    @application.get("/health")
    def health():
        return jsonify({"status": "healthy"}), 200

    @application.get("/ready")
    def ready():
        try:
            _database_check(provider)
        except Exception:
            application.logger.exception("readiness check failed")
            return jsonify({"status": "not_ready"}), 503
        return jsonify({"status": "ready"}), 200

    @application.get("/api/status")
    def status():
        response = {
            "application": "CloudOps Demo",
            "version": os.getenv("APP_VERSION", "0.1.0"),
            "environment": os.getenv("APP_ENVIRONMENT") or os.getenv("APP_ENV", "production"),
        }
        try:
            _database_check(provider)
            response["database_connectivity"] = "connected"
        except Exception:
            application.logger.exception("status database check failed")
            response["database_connectivity"] = "unavailable"
        return jsonify(response), 200

    application.logger.setLevel(logging.INFO)
    return application


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=_int_env("APP_PORT", 8080))
