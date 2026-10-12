from unittest.mock import MagicMock

from app import app as app_module


def test_root_and_status(client, monkeypatch):
    monkeypatch.setattr(app_module.pymysql, "connect", MagicMock())
    assert "CloudOps Demo" in client.get("/").get_data(as_text=True)
    response = client.get("/api/status")
    assert response.status_code == 200
    assert response.get_json()["database_connectivity"] == "connected"


def test_status_does_not_fail_when_database_is_down(client, monkeypatch):
    monkeypatch.setattr(app_module.pymysql, "connect", MagicMock(side_effect=OSError("down")))
    response = client.get("/api/status")
    assert response.status_code == 200
    assert response.get_json()["database_connectivity"] == "unavailable"
