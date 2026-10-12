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


def _aws_dashboard_status() -> dict[str, Any]:
    """Read live staging resources; no configured or failed check is reported as healthy."""
    region = os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION")
    names = ("AWS_ASG_NAME", "AWS_TARGET_GROUP_ARN", "AWS_RDS_IDENTIFIER", "AWS_ECR_REPOSITORY_NAME")
    if not region or any(not os.getenv(name) for name in names):
        return {"status": "unavailable"}
    try:
        autoscaling = boto3.client("autoscaling", region_name=region)
        elbv2 = boto3.client("elbv2", region_name=region)
        rds = boto3.client("rds", region_name=region)
        ecr = boto3.client("ecr", region_name=region)
        groups = autoscaling.describe_auto_scaling_groups(
            AutoScalingGroupNames=[os.environ["AWS_ASG_NAME"]]
        ).get("AutoScalingGroups", [])
        targets = elbv2.describe_target_health(
            TargetGroupArn=os.environ["AWS_TARGET_GROUP_ARN"]
        ).get("TargetHealthDescriptions", [])
        instances = [instance for group in groups for instance in group.get("Instances", [])]
        db_instances = rds.describe_db_instances(
            DBInstanceIdentifier=os.environ["AWS_RDS_IDENTIFIER"]
        ).get("DBInstances", [])
        images = ecr.describe_images(
            repositoryName=os.environ["AWS_ECR_REPOSITORY_NAME"],
            maxResults=1,
            filter={"tagStatus": "TAGGED"},
        ).get("imageDetails", [])
        healthy = sum(target.get("TargetHealth", {}).get("State") == "healthy" for target in targets)
        return {
            "status": "available",
            "compute": {"running": sum(i.get("LifecycleState") == "InService" for i in instances), "total": len(instances)},
            "load_balancer": {"healthy": healthy, "total": len(targets)},
            "database": db_instances[0].get("DBInstanceStatus", "unknown") if db_instances else "unavailable",
            "registry": "available" if images else "empty",
        }
    except Exception:
        logging.getLogger(__name__).exception("live AWS dashboard check failed")
        return {"status": "unavailable"}


def create_app(secret_provider: SecretProvider | None = None) -> Flask:
    application = Flask(__name__)
    provider = secret_provider or SecretProvider()
    application.config["SECRET_PROVIDER"] = provider

    @application.get("/")
    def index() -> Response:
        environment = os.getenv("APP_ENVIRONMENT") or os.getenv("APP_ENV", "unknown")
        version = os.getenv("APP_VERSION", "unknown")
        body = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>CloudOps | Live staging status</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Poppins:wght@400;600;700&display=swap" rel="stylesheet">
<style>
:root{{--ink:#102033;--muted:#6d7c91;--line:#e8edf4;--canvas:#f5f7fb;--card:#fff;--blue:#6388ff;--green:#22a06b;--red:#d34d62}}
*{{box-sizing:border-box}}body{{margin:0;color:var(--ink);background:var(--canvas);font-family:Poppins,system-ui,sans-serif}}
.page{{width:min(920px,100%);margin:auto;padding:58px 22px}}.top{{display:flex;justify-content:space-between;gap:20px;margin-bottom:30px}}
.eyebrow{{margin:0 0 8px;color:var(--blue);font-size:11px;font-weight:600;letter-spacing:.13em;text-transform:uppercase}}
h1{{margin:0;font-size:clamp(25px,5vw,38px);letter-spacing:-.05em}}p{{color:var(--muted);font-size:13px}}
.pill{{padding:9px 13px;color:var(--blue);background:#eef2ff;border-radius:999px;font:500 11px "DM Mono",monospace;white-space:nowrap}}
.grid{{display:grid;grid-template-columns:repeat(2,1fr);gap:15px}}.card{{padding:21px;background:var(--card);border:1px solid var(--line);border-radius:14px;box-shadow:0 12px 35px #172a4810}}
.card h2{{margin:0 0 17px;font-size:14px}}.value{{font-size:22px;font-weight:600;letter-spacing:-.04em}}.label{{margin-bottom:8px;color:var(--muted);font-size:11px}}
.detail{{margin-top:5px;color:var(--muted);font:10px "DM Mono",monospace}}.ok{{color:var(--green)}}.bad{{color:var(--red)}}.unknown{{color:var(--muted)}}
.wide{{grid-column:1/-1}}.checks{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}}.check{{padding:14px;background:#f8faff;border-radius:10px}}
.check .value{{margin-top:5px;font-size:16px}}footer{{margin-top:19px;color:var(--muted);font:10px "DM Mono",monospace}}a{{color:var(--blue)}}
@media(max-width:650px){{.top{{flex-direction:column}}.grid,.checks{{grid-template-columns:1fr}}.wide{{grid-column:auto}}}}
</style></head><body><main class="page"><header class="top"><div><p class="eyebrow">Live staging status</p>
<h1>CloudOps</h1><p>Only values returned by the running application and AWS are shown.</p></div>
<div class="pill">{environment} · {version}</div></header><section class="grid">
<article class="card"><div class="label">Application</div><div id="application" class="value unknown">Checking…</div><div class="detail">GET /health</div></article>
<article class="card"><div class="label">Database</div><div id="database" class="value unknown">Checking…</div><div class="detail">Secrets Manager + SELECT 1</div></article>
<article class="card wide"><h2>Live AWS resources</h2><div class="checks">
<div class="check"><div class="label">Load balancer targets</div><div id="load_balancer" class="value unknown">Checking…</div></div>
<div class="check"><div class="label">Compute instances</div><div id="compute" class="value unknown">Checking…</div></div>
<div class="check"><div class="label">RDS instance</div><div id="rds" class="value unknown">Checking…</div></div>
<div class="check"><div class="label">ECR registry</div><div id="registry" class="value unknown">Checking…</div></div>
</div></article></section><footer>Last checked: <span id="checked">—</span> · <a href="/api/dashboard">JSON</a> · <a href="/health">Health</a> · <a href="/ready">Readiness</a></footer>
</main><script>
const set=(id,value,good=false)=>{{const e=document.getElementById(id);e.textContent=value;e.className=`value ${{good?"ok":value==="Unavailable"?"bad":"unknown"}}`}};
fetch("/api/dashboard").then(r=>r.json()).then(d=>{{set("application",d.application,d.application==="Healthy");set("database",d.database,d.database==="Connected");
set("load_balancer",d.load_balancer,d.load_balancer.includes("healthy"));set("compute",d.compute,d.compute.includes("running"));set("rds",d.rds,d.rds==="available");set("registry",d.registry,d.registry==="available");document.getElementById("checked").textContent=d.checked_at;
}}).catch(()=>["application","database","load_balancer","compute","rds","registry"].forEach(id=>set(id,"Unavailable")));
</script></body></html>"""
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
            "environment": os.getenv("APP_ENVIRONMENT") or os.getenv("APP_ENV", "unknown"),
        }
        try:
            _database_check(provider)
            response["database_connectivity"] = "connected"
        except Exception:
            application.logger.exception("status database check failed")
            response["database_connectivity"] = "unavailable"
        return jsonify(response), 200

    @application.get("/api/dashboard")
    def dashboard():
        database = "Connected"
        try:
            _database_check(provider)
        except Exception:
            database = "Unavailable"
        aws = _aws_dashboard_status()
        live = aws if aws["status"] == "available" else {}
        return jsonify({
            "application": "Healthy",
            "database": database,
            "load_balancer": f'{live["load_balancer"]["healthy"]}/{live["load_balancer"]["total"]} healthy' if live else "Unavailable",
            "compute": f'{live["compute"]["running"]}/{live["compute"]["total"]} running' if live else "Unavailable",
            "rds": live.get("database", "Unavailable"),
            "registry": live.get("registry", "Unavailable"),
            "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }), 200

    application.logger.setLevel(logging.INFO)
    return application


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=_int_env("APP_PORT", 8080))
