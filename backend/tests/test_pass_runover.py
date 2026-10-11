"""Pass Runover: temporada mensal, trilhas e resgates com moedas e itens."""

from app.models import ScoreEvent, UserItem
from app.services.pass_runover import (
    PREMIUM_PRICE_COINS,
    current_season,
    free_reward,
    premium_reward,
    tier_threshold,
    unlocked_tier,
)


def _auth(registered_user):
    return {"Authorization": f"Bearer {registered_user['token']}"}


def _give_points(db_session, client, headers, points):
    user_id = client.get("/users/me", headers=headers).json()["id"]
    db_session.add(ScoreEvent(user_id=user_id, delta=points, reason="conquista"))
    db_session.commit()


def test_season_math():
    assert tier_threshold(1) == 200
    assert tier_threshold(30) == 6000
    assert unlocked_tier(0) == 0
    assert unlocked_tier(199) == 0
    assert unlocked_tier(200) == 1
    assert unlocked_tier(6000) == 30
    assert unlocked_tier(99999) == 30
    assert free_reward(1)["coins"] == 10
    assert free_reward(10)["item_id"] == "pass_banner_pioneiro"
    assert free_reward(7)["item_id"] is None
    assert premium_reward(30)["item_id"] == "pass_name_lenda"


def test_status_starts_empty(client, registered_user):
    status = client.get("/pass", headers=_auth(registered_user)).json()
    assert status["season_id"] == current_season()
    assert status["seasonal_points"] == 0
    assert status["unlocked_tier"] == 0
    assert status["premium_unlocked"] is False
    assert status["premium_price_coins"] == PREMIUM_PRICE_COINS
    assert len(status["tiers"]) == 30
    assert status["tiers"][0]["threshold"] == 200
    assert status["ends_at"]


def test_progress_unlocks_tiers(client, registered_user, db_session):
    headers = _auth(registered_user)
    _give_points(db_session, client, headers, 450)
    status = client.get("/pass", headers=headers).json()
    assert status["seasonal_points"] == 450
    assert status["unlocked_tier"] == 2
    assert status["tiers"][0]["unlocked"] is True
    assert status["tiers"][2]["unlocked"] is False


def test_free_claim_credits_coins_and_blocks_replay(client, registered_user, db_session):
    headers = _auth(registered_user)
    _give_points(db_session, client, headers, 250)
    before = client.get("/users/me", headers=headers).json()["coins_balance"]

    claimed = client.post("/pass/claim", json={"tier": 1, "track": "free"}, headers=headers)
    assert claimed.status_code == 200, claimed.text
    body = claimed.json()
    assert body["tiers"][0]["free"]["claimed"] is True
    after = client.get("/users/me", headers=headers).json()["coins_balance"]
    assert after == before + 10

    again = client.post("/pass/claim", json={"tier": 1, "track": "free"}, headers=headers)
    assert again.status_code == 409


def test_locked_tier_is_rejected(client, registered_user):
    headers = _auth(registered_user)
    denied = client.post("/pass/claim", json={"tier": 5, "track": "free"}, headers=headers)
    assert denied.status_code == 400


def test_premium_track_requires_unlock(client, registered_user, db_session):
    headers = _auth(registered_user)
    _give_points(db_session, client, headers, 1200)
    locked = client.post("/pass/claim", json={"tier": 5, "track": "premium"}, headers=headers)
    assert locked.status_code == 403

    # Sem moedas, o desbloqueio falha sem gastar nada.
    poor = client.post("/pass/premium", headers=headers)
    assert poor.status_code == 402
    assert client.get("/pass", headers=headers).json()["premium_unlocked"] is False

    _give_points(db_session, client, headers, 0)  # sem pontos extras
    db_session.commit()
    # Dá moedas via extrato direto para o teste de desbloqueio.
    from app.models import CoinTransaction
    user_id = client.get("/users/me", headers=headers).json()["id"]
    db_session.add(CoinTransaction(user_id=user_id, delta=PREMIUM_PRICE_COINS, reason="teste"))
    from app.models import User
    db_session.query(User).filter(User.id == user_id).update(
        {User.coins_balance: User.coins_balance + PREMIUM_PRICE_COINS}
    )
    db_session.commit()

    unlocked = client.post("/pass/premium", headers=headers)
    assert unlocked.status_code == 200, unlocked.text
    assert unlocked.json()["premium_unlocked"] is True
    assert client.post("/pass/premium", headers=headers).status_code == 409

    reward = client.post("/pass/claim", json={"tier": 5, "track": "premium"}, headers=headers)
    assert reward.status_code == 200, reward.text
    owned = db_session.query(UserItem).filter(
        UserItem.user_id == user_id, UserItem.item_id == "pass_avatar_explorador"
    ).count()
    assert owned == 1


def test_free_cosmetic_item_can_be_equipped(client, registered_user, db_session):
    headers = _auth(registered_user)
    _give_points(db_session, client, headers, 2000)
    claimed = client.post("/pass/claim", json={"tier": 10, "track": "free"}, headers=headers)
    assert claimed.status_code == 200, claimed.text
    equipped = client.post(
        "/shop/equip", json={"category": "banner", "item_id": "pass_banner_pioneiro"}, headers=headers
    )
    assert equipped.status_code == 200, equipped.text
    assert equipped.json()["equipped_banner"] == "pass_banner_pioneiro"


def test_pass_items_cannot_be_bought(client, registered_user):
    headers = _auth(registered_user)
    denied = client.post(
        "/shop/purchase", json={"item_id": "pass_frame_pioneiro"}, headers=headers
    )
    assert denied.status_code == 400
