from datetime import datetime, timezone

from fastapi import HTTPException

from app.routers import auth
from app.services.email import EmailDeliveryError
from app.models import PasswordResetToken


def test_password_reset_is_sent_by_email_and_code_is_single_use(client, registered_user, monkeypatch, db_session):
    sent = {}

    def capture_email(email, username, code):
        sent.update(email=email, username=username, code=code)

    monkeypatch.setattr(auth, "send_password_reset_email", capture_email)
    requested = client.post("/auth/forgot-password", json={"email": registered_user["email"]})
    unknown = client.post("/auth/forgot-password", json={"email": "missing@example.com"})

    assert requested.status_code == 200
    assert requested.json() == unknown.json()
    assert "reset_code" not in requested.json()
    assert sent["email"] == registered_user["email"]
    assert len(sent["code"]) == 12

    stored = db_session.query(PasswordResetToken).one()
    assert stored.token_hash != sent["code"]
    assert stored.expires_at.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc)

    reset = client.post("/auth/reset-password", json={
        "email": registered_user["email"],
        "reset_code": sent["code"],
        "new_password": "changed456",
    })
    assert reset.status_code == 200
    assert client.post("/auth/reset-password", json={
        "email": registered_user["email"],
        "reset_code": sent["code"],
        "new_password": "another789",
    }).status_code == 400
    assert client.post("/auth/login", json={
        "email": registered_user["email"], "password": "changed456",
    }).status_code == 200


def test_email_failure_does_not_reveal_account_existence(client, registered_user, monkeypatch):
    def fail_delivery(*_args):
        raise EmailDeliveryError("provider unavailable")

    monkeypatch.setattr(auth, "send_password_reset_email", fail_delivery)
    known = client.post("/auth/forgot-password", json={"email": registered_user["email"]})
    unknown = client.post("/auth/forgot-password", json={"email": "missing@example.com"})
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()


def test_expired_reset_code_is_rejected(client, registered_user, monkeypatch, db_session):
    sent = {}
    monkeypatch.setattr(auth, "send_password_reset_email", lambda _e, _u, code: sent.update(code=code))
    client.post("/auth/forgot-password", json={"email": registered_user["email"]})
    row = db_session.query(PasswordResetToken).one()
    row.expires_at = datetime(2000, 1, 1, tzinfo=timezone.utc)
    db_session.commit()
    response = client.post("/auth/reset-password", json={
        "email": registered_user["email"], "reset_code": sent["code"], "new_password": "changed456",
    })
    assert response.status_code == 400


def test_five_invalid_codes_invalidate_the_reset_code(client, registered_user, monkeypatch):
    sent = {}
    monkeypatch.setattr(auth, "send_password_reset_email", lambda _e, _u, code: sent.update(code=code))
    client.post("/auth/forgot-password", json={"email": registered_user["email"]})
    for _ in range(5):
        response = client.post("/auth/reset-password", json={
            "email": registered_user["email"], "reset_code": "000000000000",
            "new_password": "changed456",
        })
        assert response.status_code == 400
    valid = client.post("/auth/reset-password", json={
        "email": registered_user["email"], "reset_code": sent["code"],
        "new_password": "changed456",
    })
    assert valid.status_code == 400
