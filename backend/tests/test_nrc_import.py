import os
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

_tmp = tempfile.TemporaryDirectory()
os.environ['DATABASE_URL'] = 'sqlite:///' + _tmp.name + '/test.db'
os.environ['SECRET_KEY'] = 'local-test-signing-key-for-runover-tests'

from fastapi.testclient import TestClient
from app.core.database import Base, SessionLocal, engine, initialize_database
from app.geometry import polygon_to_geojson
from app.main import app
from app.models import Run, Territory
from app.services import nrc


class _FakeResponse:
    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code

    def json(self):
        return self._payload


def _nrc_activity(activity_id: str, minutes_ago: float, *, with_gps: bool = True) -> dict:
    start_ms = int((datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)).timestamp() * 1000)
    lats = [-23.6489, -23.6490, -23.6491, -23.6490, -23.6489]
    lngs = [-46.8523, -46.8524, -46.8525, -46.8524, -46.8523]
    metrics = []
    if with_gps:
        metrics.append({"type": "latitude", "values": [
            {"start_epoch_ms": start_ms + i * 60000, "value": v} for i, v in enumerate(lats)]})
        metrics.append({"type": "longitude", "values": [
            {"start_epoch_ms": start_ms + i * 60000, "value": v} for i, v in enumerate(lngs)]})
    metrics.append({"type": "heart_rate", "values": [
        {"start_epoch_ms": start_ms + i * 60000, "value": 140 + i} for i in range(len(lats))]})
    return {
        "id": activity_id,
        "type": "run",
        "tags": {"com.nike.name": "Morning run", "com.nike.running.runtype": "outdoors"},
        "metrics": metrics,
    }


class NrcImportTests(unittest.TestCase):
    def setUp(self):
        Base.metadata.drop_all(engine)
        initialize_database()
        self.client = TestClient(app)
        self.client.__enter__()
        response = self.client.post('/auth/register', json={
            'full_name': 'Test Runner', 'username': 'nrcrunner',
            'email': 'nrc@example.com', 'password': 'Password123', 'accept_terms': True,
        })
        self.assertEqual(response.status_code, 201, response.text)
        self.headers = {'Authorization': 'Bearer ' + response.json()['access_token']}

    def tearDown(self):
        self.client.__exit__(None, None, None)

    def test_activity_to_run_payload_extracts_gps_series(self):
        activity = _nrc_activity("0019f189-d32f-437f-a4d4-ef4f15304324", 120)
        payload = nrc.activity_to_run_payload(activity)
        self.assertIsNotNone(payload)
        self.assertEqual(payload["id"], "0019f189-d32f-437f-a4d4-ef4f15304324")
        self.assertEqual(payload["request_id"], "0019f189-d32f-437f-a4d4-ef4f15304324")
        self.assertEqual(payload["name"], "Morning run")
        self.assertEqual(len(payload["track"]), 5)
        first = payload["track"][0]
        self.assertEqual(first["segment"], 0)
        self.assertTrue(first["timestamp"].endswith("+00:00"))
        self.assertEqual(first["lat"], -23.6489)

    def test_activity_without_gps_is_ignored(self):
        payload = nrc.activity_to_run_payload(_nrc_activity("no-gps-activity", 120, with_gps=False))
        self.assertIsNone(payload)

    def test_fetch_activities_paginates_and_skips_manual_runs(self):
        pages = [
            {"activities": [
                {"id": "run-1", "type": "run", "tags": {"com.nike.running.runtype": "outdoors"}},
                {"id": "manual-1", "type": "run", "tags": {"com.nike.running.runtype": "manual"}},
                {"id": "ride-1", "type": "ride"},
            ], "paging": {"before_id": "page-2"}},
            {"activities": [
                {"id": "run-2", "type": "run", "tags": {"com.nike.running.runtype": "outdoors"}},
            ], "paging": {}},
        ]
        responses = [_FakeResponse(p) for p in pages]
        with patch("app.services.nrc.httpx.get", side_effect=responses):
            ids = nrc.fetch_activities("valid-token")
        self.assertEqual(ids, ["run-1", "run-2"])

    def test_fetch_activities_rejects_invalid_token(self):
        response = _FakeResponse({"error_id": "invalid"})
        with patch("app.services.nrc.httpx.get", return_value=response):
            with self.assertRaises(nrc.NikeApiError):
                nrc.fetch_activities("bad-token")

    def test_import_saves_recent_runs_and_skips_old_ones(self):
        recent = _nrc_activity("11111111-1111-1111-1111-111111111111", 120)
        old = _nrc_activity("22222222-2222-2222-2222-222222222222", 60 * 24 * 30)
        details = {recent["id"]: recent, old["id"]: old}
        with patch("app.routers.imports.fetch_activities", return_value=list(details)), \
             patch("app.routers.imports.fetch_activity_details", side_effect=lambda token, aid: details[aid]):
            response = self.client.post("/import/nrc/runs", json={"token": "nrc-access-token-123"}, headers=self.headers)
        self.assertEqual(response.status_code, 200, response.text)
        body = response.json()
        self.assertEqual(body["imported_count"], 1)
        self.assertEqual(body["skipped_count"], 1)
        self.assertEqual(body["imported"][0]["name"], "Morning run")
        self.assertIn("7 dias", body["skipped"][0]["reason"])

    def test_import_is_idempotent(self):
        activity = _nrc_activity("33333333-3333-3333-3333-333333333333", 60)
        with patch("app.routers.imports.fetch_activities", return_value=[activity["id"]]), \
             patch("app.routers.imports.fetch_activity_details", side_effect=lambda token, aid: activity):
            first = self.client.post("/import/nrc/runs", json={"token": "nrc-access-token-123"}, headers=self.headers)
            second = self.client.post("/import/nrc/runs", json={"token": "nrc-access-token-123"}, headers=self.headers)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.json()["imported_count"], 1)
        with SessionLocal() as db:
            self.assertEqual(db.query(Run).count(), 1)  # reimportação não duplica

    def test_import_rejects_invalid_token(self):
        with patch("app.routers.imports.fetch_activities", side_effect=nrc.NikeApiError("Token inválido")):
            response = self.client.post("/import/nrc/runs", json={"token": "invalid-token-but-long-enough"}, headers=self.headers)
        self.assertEqual(response.status_code, 401)

    def test_import_rejects_missing_token(self):
        response = self.client.post("/import/nrc/runs", json={}, headers=self.headers)
        self.assertEqual(response.status_code, 422)

    def test_nearby_territories_filters_by_radius(self):
        with SessionLocal() as db:
            db.add(Territory(name="Perto", geojson=polygon_to_geojson(
                [(-23.6489, -46.8523), (-23.6480, -46.8510), (-23.6470, -46.8520), (-23.6489, -46.8523)]),
                radius_m=80, relevance=1))
            db.add(Territory(name="Longe", geojson=polygon_to_geojson(
                [(-23.5500, -46.6500), (-23.5490, -46.6490), (-23.5480, -46.6500), (-23.5500, -46.6500)]),
                radius_m=90, relevance=1))
            db.commit()
        response = self.client.get("/territories/nearby", params={
            "lat": -23.6489, "lng": -46.8523, "radius_km": 5,
        }, headers=self.headers)
        self.assertEqual(response.status_code, 200, response.text)
        names = {t["name"] for t in response.json()}
        self.assertIn("Perto", names)
        self.assertNotIn("Longe", names)

    def test_nearby_territories_requires_auth(self):
        response = self.client.get("/territories/nearby", params={"lat": -23.6, "lng": -46.8})
        self.assertEqual(response.status_code, 401)


if __name__ == "__main__":
    unittest.main()
