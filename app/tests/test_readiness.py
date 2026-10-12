from unittest.mock import MagicMock

from app import app as app_module


def test_ready_checks_database(client, monkeypatch):
    connection = MagicMock()
    connection.cursor.return_value.__enter__.return_value.fetchone.return_value = (1,)
    monkeypatch.setattr(app_module.pymysql, "connect", MagicMock(return_value=connection))
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ready"}


def test_ready_returns_503_when_database_is_unavailable(client, monkeypatch):
    monkeypatch.setattr(app_module.pymysql, "connect", MagicMock(side_effect=OSError("down")))
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.get_json() == {"status": "not_ready"}
