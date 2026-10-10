"""Extrato de pontos da equipe: o card "Pontos" precisa dizer de onde vem."""

from uuid import uuid4

from app.models import ScoreEvent, Territory


def _auth(registered_user):
    return {"Authorization": f"Bearer {registered_user['token']}"}


def _team_id(client, headers):
    response = client.post(
        "/teams", json={"name": "Lobos de Teste"}, headers=headers
    )
    assert response.status_code == 201
    return response.json()["id"]


def _conquest_event(db_session, team_id, name, delta):
    territory = Territory(
        name=name,
        geojson='{"type":"Point","coordinates":[0,0]}',
        radius_m=50,
        relevance=1,
    )
    db_session.add(territory)
    db_session.flush()
    event = ScoreEvent(
        team_id=team_id,
        territory_id=territory.id,
        delta=delta,
        reason="conquista",
    )
    db_session.add(event)
    db_session.commit()
    return event


def test_history_lists_only_the_team_events(client, registered_user, db_session):
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    user_id = client.get("/users/me", headers=headers).json()["id"]
    _conquest_event(db_session, team_id, "Praça Central", 30)
    _conquest_event(db_session, team_id, "Orla", 20)
    # O mesmo usuário correndo sozinho não pontua para a equipe (RN15).
    db_session.add(
        ScoreEvent(user_id=user_id, delta=99, reason="conquista")
    )
    db_session.commit()

    entries = client.get(f"/teams/{team_id}/history", headers=headers).json()

    assert [e["delta"] for e in entries] == [20, 30]
    assert {e["territory_name"] for e in entries} == {"Praça Central", "Orla"}
    assert all(e["reason"] == "conquista" for e in entries)


def test_history_marks_a_lost_territory_without_a_name(client, registered_user, db_session):
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    event = _conquest_event(db_session, team_id, "Bosque", 15)
    db_session.add(
        ScoreEvent(
            id=str(uuid4()),
            team_id=team_id,
            delta=-15,
            reason="perda",
        )
    )
    db_session.commit()

    entries = client.get(f"/teams/{team_id}/history", headers=headers).json()

    assert entries[0]["delta"] == -15
    assert entries[0]["territory_name"] is None
    assert event.delta == 15


def test_history_of_unknown_team_is_404(client, registered_user):
    headers = _auth(registered_user)
    assert client.get("/teams/nope/history", headers=headers).status_code == 404
