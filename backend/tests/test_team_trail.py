"""A trilha de nível da equipe: quanto custa cada nível e o que ele libera."""

from app.models import ScoreEvent


def _auth(registered_user):
    return {"Authorization": f"Bearer {registered_user['token']}"}


def _team_id(client, headers):
    response = client.post(
        "/teams", json={"name": "Lobos de Teste"}, headers=headers
    )
    assert response.status_code == 201
    return response.json()["id"]


def _trail(client, headers):
    return client.get("/teams/mine", headers=headers).json()["level_trail"]


def test_trail_covers_the_whole_base_for_a_new_team(client, registered_user):
    headers = _auth(registered_user)
    _team_id(client, headers)
    trail = _trail(client, headers)

    assert [stop["level"] for stop in trail] == [1, 2, 3, 4]
    assert [stop["zone_capacity"] for stop in trail] == [7, 19, 37, 61]
    assert [stop["points_required"] for stop in trail] == [0, 150, 450, 900]
    assert [stop["reached"] for stop in trail] == [True, False, False, False]


def test_trail_marks_reached_stops_and_keeps_a_head_up_view(
    client, registered_user, db_session
):
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    db_session.add(ScoreEvent(team_id=team_id, delta=450, reason="conquista"))
    db_session.commit()

    trail = _trail(client, headers)

    # 450 pts coloca a equipe no nível 3; a trilha mostra o anel inteiro da base
    # e mais dois níveis à frente, então vão 1..5.
    assert [stop["level"] for stop in trail] == [1, 2, 3, 4, 5]
    assert [stop["reached"] for stop in trail] == [True, True, True, False, False]
    assert trail[-1]["level"] == 5


def test_trail_stops_growing_zones_after_the_last_ring(client, registered_user, db_session):
    headers = _auth(registered_user)
    team_id = _team_id(client, headers)
    db_session.add(ScoreEvent(team_id=team_id, delta=150 * 20, reason="conquista"))
    db_session.commit()

    trail = _trail(client, headers)

    assert trail[3]["zone_capacity"] == 61
    assert all(stop["zone_capacity"] == 61 for stop in trail[3:])
    assert all(stop["reached"] for stop in trail[:-2])
