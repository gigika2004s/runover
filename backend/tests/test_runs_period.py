"""Filtro de período do histórico: `GET /runs?since=...` corta no servidor."""

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.models import Run


def _headers(registered_user):
    return {"Authorization": f"Bearer {registered_user['token']}"}


def _user_id(client, headers):
    return client.get("/users/me", headers=headers).json()["id"]


def _add_run(db_session, user_id, name, started_at):
    db_session.add(Run(
        id=str(uuid4()),
        user_id=user_id,
        team_id=None,
        request_hash=str(uuid4()),
        track_hash=str(uuid4()),
        track_json="[]",
        started_at=started_at,
        ended_at=started_at + timedelta(minutes=20),
        distance_m=1000,
        duration_seconds=1200,
        name=name,
        result_json='{"claim": null, "claim_error": null}',
    ))
    db_session.commit()


def test_lista_sem_corte_traz_tudo(client, registered_user, db_session):
    headers = _headers(registered_user)
    uid = _user_id(client, headers)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    _add_run(db_session, uid, "Antiga", now - timedelta(days=90))
    _add_run(db_session, uid, "Recente", now - timedelta(hours=1))

    names = [r["name"] for r in client.get("/runs", headers=headers).json()]
    assert names == ["Recente", "Antiga"]


def test_corte_deixa_só_o_que_começa_na_data_limite(client, registered_user, db_session):
    headers = _headers(registered_user)
    uid = _user_id(client, headers)
    month_start = datetime(2026, 10, 1, 0, 0, 0)
    _add_run(db_session, uid, "Setembro", month_start - timedelta(minutes=1))
    _add_run(db_session, uid, "No limite", month_start)
    _add_run(db_session, uid, "Outubro", month_start + timedelta(days=3))

    body = client.get("/runs", headers=headers, params={"since": month_start.isoformat()}).json()
    # O corte é inclusivo: a corrida que começa exatamente no marco entra.
    assert [r["name"] for r in body] == ["Outubro", "No limite"]


def test_corte_com_fuso_é_convertido_para_utc(client, registered_user, db_session):
    headers = _headers(registered_user)
    uid = _user_id(client, headers)
    # `started_at` é UTC ingênuo; meio-dia em -03:00 são 15:00 UTC.
    cutoff_utc = datetime(2026, 10, 5, 15, 0, tzinfo=timezone.utc).replace(tzinfo=None)
    _add_run(db_session, uid, "Antes", cutoff_utc - timedelta(minutes=1))
    _add_run(db_session, uid, "Depois", cutoff_utc + timedelta(minutes=1))
    sao_paulo = timezone(timedelta(hours=-3))
    cutoff = datetime(2026, 10, 5, 12, 0, tzinfo=sao_paulo).isoformat()

    body = client.get("/runs", headers=headers, params={"since": cutoff}).json()
    assert [r["name"] for r in body] == ["Depois"]


def test_corte_nao_quebra_a_paginacao(client, registered_user, db_session):
    headers = _headers(registered_user)
    uid = _user_id(client, headers)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    for index in range(4):
        _add_run(db_session, uid, f"Mês {index}", now - timedelta(days=index))
    _add_run(db_session, uid, "Velha", now - timedelta(days=40))

    params = {"since": (now - timedelta(days=5)).isoformat(), "limit": 2}
    first = client.get("/runs", headers=headers, params=params).json()
    second = client.get("/runs", headers=headers, params={**params, "offset": 2}).json()
    assert [r["name"] for r in first] == ["Mês 0", "Mês 1"]
    assert [r["name"] for r in second] == ["Mês 2", "Mês 3"]
    # A paginação não "vaza" corrida fora do período.
    assert "Velha" not in [r["name"] for r in first + second]


def test_corte_futuro_devolve_lista_vazia(client, registered_user, db_session):
    headers = _headers(registered_user)
    uid = _user_id(client, headers)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    _add_run(db_session, uid, "Hoje", now)

    body = client.get("/runs", headers=headers,
                      params={"since": (now + timedelta(days=1)).isoformat()}).json()
    assert body == []
    # Sem o parâmetro a corrida continua lá: o filtro é aditivo, não muda a
    # resposta de quem não usa o período.
    assert [r["name"] for r in client.get("/runs", headers=headers).json()] == ["Hoje"]
