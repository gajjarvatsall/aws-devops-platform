from unittest.mock import MagicMock

from app import app as app_module


def test_root_and_status(client, monkeypatch):
    monkeypatch.setattr(app_module.pymysql, "connect", MagicMock())
    page = client.get("/").get_data(as_text=True)
    assert "Live staging status" in page
    assert "Application rollout active" not in page
    response = client.get("/api/status")
    assert response.status_code == 200
    assert response.get_json()["database_connectivity"] == "connected"


def test_status_does_not_fail_when_database_is_down(client, monkeypatch):
    monkeypatch.setattr(app_module.pymysql, "connect", MagicMock(side_effect=OSError("down")))
    response = client.get("/api/status")
    assert response.status_code == 200
    assert response.get_json()["database_connectivity"] == "unavailable"


def test_dashboard_does_not_invent_aws_status(client, monkeypatch):
    monkeypatch.setattr(app_module.pymysql, "connect", MagicMock())
    response = client.get("/api/dashboard")
    assert response.status_code == 200
    assert response.get_json()["load_balancer"] == "Unavailable"
    assert response.get_json()["registry"] == "Unavailable"
