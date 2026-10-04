from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.models import ClaimReceipt, Run, ScoreEvent, Territory


def _track():
    start = datetime.now(timezone.utc) - timedelta(minutes=3)
    points = [(-23.6489, -46.8523), (-23.6489, -46.8520), (-23.6486, -46.8520), (-23.6489, -46.8523)]
    return [
        {"lat": lat, "lng": lng, "timestamp": (start + timedelta(seconds=60 * i)).isoformat()}
        for i, (lat, lng) in enumerate(points)
    ]


def test_run_retry_is_idempotent_and_reusing_id_for_other_payload_conflicts(client, registered_user, db_session):
    headers = {"Authorization": f"Bearer {registered_user['token']}"}
    run_id = str(uuid4())
    body = {
        "id": run_id,
        "request_id": run_id,
        "track": _track(),
        "conquer": True,
    }
    first = client.post("/runs", json=body, headers=headers)
    retry = client.post("/runs", json=body, headers=headers)

    assert first.status_code == retry.status_code == 200
    assert first.json() == retry.json()
    assert db_session.query(Territory).count() == 1
    assert db_session.query(ScoreEvent).count() == 1
    assert db_session.query(ClaimReceipt).count() == 1
    assert db_session.query(Run).count() == 1

    reused = {**body, "name": "different run"}
    assert client.post("/runs", json=reused, headers=headers).status_code == 409


def test_unclosed_track_does_not_create_a_territory(client, registered_user, db_session):
    headers = {"Authorization": f"Bearer {registered_user['token']}"}
    track = _track()
    track[-1]["lat"] += 0.01
    response = client.post("/runs", json={
        "id": str(uuid4()),
        "request_id": "unclosed-request-001",
        "track": track,
        "conquer": True,
    }, headers=headers)
    assert response.status_code == 400
    assert db_session.query(Territory).count() == 0
    assert db_session.query(ScoreEvent).count() == 0
