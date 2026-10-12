"""Desafios do dia: sorteio determinístico, medição real e resgate que paga uma vez.

O que a tela de Corridas mostra depende destes contratos: os três desafios do
dia saem do apelido e da data, o progresso vem das corridas salvas no servidor,
e o resgate credita pontos de temporada e dracmas uma única vez por dia.
"""

from datetime import date, datetime, timedelta, timezone
from uuid import uuid4

from auth_helpers import auth_headers
from app.models import ScoreEvent
from app.services.daily_challenges import (
    POOL,
    REWARDS,
    DaySummary,
    draw,
    local_day,
    measure,
    personalized,
    summarize,
)


def _track(km=4.0, step_minutes=1.0):
    """Percurso reto de `km` quilômetros a ~4 min/km, terminando agora."""
    steps = max(2, int(km * 1000 / 222.6))
    end = datetime.now(timezone.utc).replace(microsecond=0)
    start = end - timedelta(minutes=step_minutes * steps)
    return [
        {
            "lat": -23.55 + 0.002 * i,
            "lng": -46.64,
            "timestamp": (start + timedelta(minutes=step_minutes * i)).isoformat(),
        }
        for i in range(steps + 1)
    ]


def _user(client, username):
    return auth_headers(
        client, username=username, email=f"{username}@example.com"
    )


def _save_run(client, headers):
    run_id = str(uuid4())
    response = client.post(
        "/runs",
        json={"id": run_id, "request_id": run_id, "track": _track()},
        headers=headers,
    )
    assert response.status_code == 200, response.text


# ---------- o sorteio ----------


def test_draw_is_stable_inside_the_day_and_changes_across_days():
    today = [c.id for c in draw("misaia", date(2026, 10, 12), 12.4, 5.2)]
    assert today == [c.id for c in draw("misaia", date(2026, 10, 12), 12.4, 5.2)]
    assert today != [c.id for c in draw("misaia", date(2026, 10, 13), 12.4, 5.2)]
    assert today != [c.id for c in draw("ana", date(2026, 10, 12), 12.4, 5.2)]


def test_draw_returns_three_distinct_challenges_with_the_personal_last():
    picked = draw("misaia", date(2026, 10, 12), 12.4, 5.2)
    assert len(picked) == 3
    assert picked[-1].id == "personal"
    assert len({c.id for c in picked}) == 3


def test_reward_comes_from_the_rarity():
    assert REWARDS == {"comum": (20, 0), "raro": (40, 30), "épico": (80, 60)}
    for challenge in draw("misaia", date(2026, 10, 12), 0, 0):
        assert (challenge.points, challenge.coins) == REWARDS[challenge.rarity]


def test_personal_target_follows_the_history_between_3_and_15_km():
    assert personalized(0, 0).target == 3.0
    assert personalized(14, 2).target == 4.0
    assert personalized(700, 100).target == 15.0


# ---------- a medição ----------


def test_measure_reads_every_kind_from_the_day_summary():
    summary = DaySummary(
        count=2,
        distance_km=6.4,
        minutes=45,
        start_hours=(6, 21),
        fastest_pace_min_km=5.5,
    )
    for challenge in POOL:
        value, done = measure(challenge, summary)
        if challenge.kind == "count":
            assert (value, done) == (2, challenge.target <= 2)
        elif challenge.kind == "distance":
            assert (value, done) == (6.4, challenge.target <= 6.4)
        elif challenge.kind == "duration":
            assert (value, done) == (45, challenge.target <= 45)
        elif challenge.kind in ("dawn", "night"):
            assert (value, done) == (1, True)
        elif challenge.kind == "pace":
            assert (value, done) == (5.5, 5.5 < challenge.target)


def test_summarize_only_counts_the_requested_local_day():
    now = datetime.now(timezone.utc).replace(microsecond=0)
    runs = [
        (now - timedelta(hours=1), 1000.0, 300),
        (now - timedelta(days=3), 5000.0, 1500),
    ]
    summary = summarize(runs, local_day(now, 0), 0)
    assert summary.count == 1
    assert summary.distance_km == 1.0
    assert summary.minutes == 5


def test_summarize_measures_pace_only_from_runs_of_at_least_one_km():
    """Um trote de 12 m não pode entregar o épico "Racho afiado"."""
    now = datetime.now(timezone.utc).replace(microsecond=0)
    sprint = [(now - timedelta(minutes=2), 12.0, 3)]
    assert summarize(sprint, local_day(now, 0), 0).fastest_pace_min_km is None
    real = summarize(
        [(now - timedelta(minutes=2), 1000.0, 300)], local_day(now, 0), 0
    )
    assert real.fastest_pace_min_km == 5.0


# ---------- as rotas ----------


def test_challenges_endpoint_returns_todays_three(client):
    headers = _user(client, "corredora")
    body = client.get("/runs/challenges", headers=headers).json()
    assert body["day"] == local_day(datetime.now(timezone.utc), 0).isoformat()
    assert len(body["challenges"]) == 3
    for item in body["challenges"]:
        assert set(item) == {
            "id", "title", "detail", "unit", "target", "rarity", "kind",
            "value", "done", "points", "coins", "claimed",
        }
        assert item["claimed"] is False
        assert item["value"] == 0
    assert body["challenges"][-1]["id"] == "personal"


def test_progress_reports_the_real_daily_bonus(client):
    """O rodapé do estado vazio cita o bônus do servidor, não um número do mock."""
    headers = _user(client, "bonificada")
    empty = client.get("/runs/progress", headers=headers).json()
    assert empty["daily_bonus"] == 20
    assert empty["daily_bonus_pending"] is True

    _save_run(client, headers)
    after = client.get("/runs/progress", headers=headers).json()
    started_at = datetime.fromisoformat(client.get("/runs", headers=headers).json()[0]["started_at"])
    ran_today = started_at.astimezone(timezone.utc).date() == datetime.now(timezone.utc).date()
    assert after["daily_bonus"] == 20
    assert after["daily_bonus_pending"] is (not ran_today)


def test_personal_target_freezes_at_midnight(client):
    """Correr hoje não pode deixar o desafio de hoje mais difícil."""
    headers = _user(client, "congelada")
    before = next(
        c for c in client.get("/runs/challenges", headers=headers).json()["challenges"]
        if c["id"] == "personal"
    )
    _save_run(client, headers)
    after = next(
        c for c in client.get("/runs/challenges", headers=headers).json()["challenges"]
        if c["id"] == "personal"
    )
    assert after["target"] == before["target"] == 3.0
    assert after["done"] is True


def test_personal_challenge_pays_after_a_run_and_only_once(client, db_session):
    headers = _user(client, "resgatadora")
    before = client.get("/runs/challenges", headers=headers).json()
    personal = next(c for c in before["challenges"] if c["id"] == "personal")
    assert personal["done"] is False
    assert (personal["points"], personal["coins"]) == (80, 60)

    too_early = client.post(
        "/runs/challenges/claim", json={"challenge_id": "personal"}, headers=headers
    )
    assert too_early.status_code == 400
    assert "Complete o desafio" in too_early.json()["detail"]

    _save_run(client, headers)
    after_run = client.get("/runs/challenges", headers=headers).json()
    personal = next(c for c in after_run["challenges"] if c["id"] == "personal")
    assert personal["done"] is True and personal["claimed"] is False

    wallet_before = client.get("/shop/wallet", headers=headers).json()["balance"]
    claimed = client.post(
        "/runs/challenges/claim", json={"challenge_id": "personal"}, headers=headers
    )
    assert claimed.status_code == 200, claimed.text
    item = next(c for c in claimed.json()["challenges"] if c["id"] == "personal")
    assert item["claimed"] is True and item["done"] is True
    balance = client.get("/shop/wallet", headers=headers).json()["balance"]
    assert balance == wallet_before + 60
    events = db_session.query(ScoreEvent).filter_by(reason="desafio do dia").all()
    assert [event.delta for event in events] == [80]

    repeat = client.post(
        "/runs/challenges/claim", json={"challenge_id": "personal"}, headers=headers
    )
    assert repeat.status_code == 409
    assert "já foi resgatado" in repeat.json()["detail"]


def test_a_run_cannot_pay_the_same_challenge_on_two_days(client):
    """O fuso é do aparelho, mas uma corrida paga um único dia.

    -720 e +840 são 26 horas apartados: para qualquer instante eles caem em
    datas diferentes, então a mesma corrida cabe nos dois "dias" e, sem a trava
    do recibo, credita a recompensa duas vezes.
    """
    headers = _user(client, "fusadora")
    _save_run(client, headers)

    first = client.post(
        "/runs/challenges/claim",
        json={"challenge_id": "personal", "utc_offset_minutes": -720},
        headers=headers,
    )
    assert first.status_code == 200, first.text
    balance = client.get("/shop/wallet", headers=headers).json()["balance"]

    second = client.post(
        "/runs/challenges/claim",
        json={"challenge_id": "personal", "utc_offset_minutes": 840},
        headers=headers,
    )
    assert second.status_code == 409, second.text
    assert "outro dia" in second.json()["detail"]
    assert client.get("/shop/wallet", headers=headers).json()["balance"] == balance


def test_claim_rejects_a_challenge_that_is_not_in_todays_draw(client):
    headers = _user(client, "espertinha")
    drawn = {
        c["id"] for c in client.get("/runs/challenges", headers=headers).json()["challenges"]
    }
    outside = next(challenge.id for challenge in POOL if challenge.id not in drawn)
    response = client.post(
        "/runs/challenges/claim", json={"challenge_id": outside}, headers=headers
    )
    assert response.status_code == 404
    assert "não está no seu sorteio" in response.json()["detail"]
