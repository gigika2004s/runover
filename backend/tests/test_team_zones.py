"""As zonas da base da equipe são a leitura das conquistas reais de território."""

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.models import ScoreEvent, Territory, TerritoryOwnership, User


def _auth(registered_user):
    return {"Authorization": f"Bearer {registered_user['token']}"}


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _team_id(client, headers):
    response = client.post(
        "/teams", json={"name": "Lobos de Teste"}, headers=headers
    )
    assert response.status_code == 201
    return response.json()["id"]


def _conquer_for_team(db_session, team_id, name, points, minutes_ago):
    territory = Territory(
        name=name,
        geojson='{"type":"Point","coordinates":[0,0]}',
        radius_m=50,
        relevance=1,
    )
    db_session.add(territory)
    db_session.flush()
    db_session.add(
        TerritoryOwnership(
            id=str(uuid4()),
            territory_id=territory.id,
            owner_team_id=team_id,
            points=points,
            conquered_at=_now() - timedelta(minutes=minutes_ago),
        )
    )
    db_session.commit()
    return territory


def _zones(client, headers):
    detail = client.get("/teams/mine", headers=headers).json()
    return detail["territories"], detail["territories_count"]


def test_empty_team_has_no_zones_lit(client, registered_user):
    headers = _auth(registered_user)
    _team_id(client, headers)
    territories, count = _zones(client, headers)
    assert territories == []
    assert count == 0


def test_zones_are_the_real_conquests_in_conquest_order(client, registered_user, db_session):
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    _conquer_for_team(db_session, team_id, "Praça Central", 30, minutes_ago=120)
    _conquer_for_team(db_session, team_id, "Parque do Bairro", 10, minutes_ago=60)
    _conquer_for_team(db_session, team_id, "Orla", 20, minutes_ago=10)

    territories, count = _zones(client, headers)

    assert count == 3
    assert [z["name"] for z in territories] == [
        "Praça Central",
        "Parque do Bairro",
        "Orla",
    ]
    assert [z["points"] for z in territories] == [30, 10, 20]
    assert territories[0]["conquered_at"] < territories[-1]["conquered_at"]


def test_losing_a_territory_takes_its_zone_back(client, registered_user, db_session):
    """A base mostra a posse atual: território retomado por outro deixa de
    acender célula."""
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    territory = _conquer_for_team(db_session, team_id, "Bosque", 15, minutes_ago=90)
    rival = User(
        id=str(uuid4()),
        full_name="Rival",
        username="rival",
        email="rival@example.com",
        password_hash="x",
    )
    db_session.add(rival)
    db_session.flush()
    db_session.add(
        TerritoryOwnership(
            id=str(uuid4()),
            territory_id=territory.id,
            owner_user_id=rival.id,
            points=15,
            conquered_at=_now() - timedelta(minutes=5),
        )
    )
    db_session.commit()

    territories, count = _zones(client, headers)

    assert territories == []
    assert count == 0


def test_zone_capacity_follows_the_published_table(client, registered_user, db_session):
    """A capacidade é regra do servidor: 7 no nível 1, +1 anel por nível."""
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    assert client.get("/teams/mine", headers=headers).json()["zone_capacity"] == 7

    db_session.add(ScoreEvent(team_id=team_id, delta=150, reason="conquista"))
    db_session.commit()

    detail = client.get("/teams/mine", headers=headers).json()
    assert detail["level"] == 2
    assert detail["zone_capacity"] == 19


def test_zone_capacity_stops_growing_at_the_last_ring(client, registered_user, db_session):
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    db_session.add(ScoreEvent(team_id=team_id, delta=150 * 20, reason="conquista"))
    db_session.commit()

    detail = client.get("/teams/mine", headers=headers).json()
    assert detail["level"] > 4
    assert detail["zone_capacity"] == 61
