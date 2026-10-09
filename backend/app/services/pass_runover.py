"""Pass Runover: temporada mensal movida a XP (pontos da temporada).

30 tiers por temporada (`YYYY-MM`, vira no dia 1, não resgatado expira),
trilha gratuita e trilha premium (desbloqueio único por temporada, pago em
moedas). O progresso é a soma dos pontos do jogador na temporada — time e
loja não entram.

Recompensas: moedas (via extrato auditável) + cosméticos exclusivos do
passe (`scope == 'pass'`, impossíveis de comprar: só o resgate concede).
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models import PassClaim, PassPremium
from app.services.scoring import total_score

# XP (pontos da temporada) acumulado para liberar cada tier (1..30).
POINTS_PER_TIER = 200
MAX_TIER = 30

# Trilha premium: desbloqueio único por temporada, pago em moedas.
PREMIUM_PRICE_COINS = 1000


def current_season(now: datetime | None = None) -> str:
    """`YYYY-MM` da temporada vigente (mês corrido, UTC)."""
    now = now or datetime.now(timezone.utc)
    return f"{now.year:04d}-{now.month:02d}"


def season_bounds(season_id: str) -> tuple[datetime, datetime]:
    """(início inclusivo, fim exclusivo) da temporada, em UTC naive
    (mesmo padrão das corridas e eventos de pontos)."""
    year, month = (int(p) for p in season_id.split("-"))
    start = datetime(year, month, 1)
    if month == 12:
        end = datetime(year + 1, 1, 1)
    else:
        end = datetime(year, month + 1, 1)
    return start, end


def tier_threshold(tier: int) -> int:
    """Pontos acumulados na temporada para liberar o tier."""
    return POINTS_PER_TIER * tier


def seasonal_points(db: Session, user_id: str, season_id: str | None = None) -> int:
    """Soma dos pontos do jogador dentro da temporada."""
    start, _ = season_bounds(season_id or current_season())
    return total_score(db, user_id, since=start)


def unlocked_tier(seasonal_pts: int) -> int:
    """Maior tier liberado pelos pontos (0 = nenhum)."""
    tier = seasonal_pts // POINTS_PER_TIER
    return max(0, min(MAX_TIER, tier))


def free_reward(tier: int) -> dict:
    """Recompensa da trilha gratuita: moedas + cosmético a cada 10 tiers."""
    coins = tier * 10
    item = {10: "pass_banner_pioneiro", 20: "pass_frame_pioneiro", 30: "pass_effect_pioneiro"}.get(tier)
    return {"coins": coins, "item_id": item}


def premium_reward(tier: int) -> dict:
    """Recompensa da trilha premium: mais moedas + exclusivos."""
    coins = tier * 25
    item = {
        5: "pass_avatar_explorador",
        10: "pass_name_capitao",
        15: "pass_banner_conquistador",
        20: "pass_frame_conquistador",
        25: "pass_effect_tormenta",
        30: "pass_name_lenda",
    }.get(tier)
    return {"coins": coins, "item_id": item}


def is_premium(db: Session, user_id: str, season_id: str) -> bool:
    return (
        db.query(PassPremium)
        .filter(PassPremium.user_id == user_id, PassPremium.season_id == season_id)
        .first()
        is not None
    )


def claimed(db: Session, user_id: str, season_id: str) -> set[tuple[int, str]]:
    """{(tier, track)} já resgatados na temporada."""
    return {
        (c.tier, c.track)
        for c in db.query(PassClaim)
        .filter(PassClaim.user_id == user_id, PassClaim.season_id == season_id)
        .all()
    }


def pass_status(db: Session, user_id: str) -> dict:
    """Tudo que a tela do passe precisa em uma resposta."""
    season_id = current_season()
    _, end = season_bounds(season_id)
    points = seasonal_points(db, user_id, season_id)
    top = unlocked_tier(points)
    premium = is_premium(db, user_id, season_id)
    taken = claimed(db, user_id, season_id)
    tiers = [
        {
            "tier": tier,
            "threshold": tier_threshold(tier),
            "unlocked": tier <= top,
            "free": {**free_reward(tier), "claimed": (tier, "free") in taken},
            "premium": {**premium_reward(tier), "claimed": (tier, "premium") in taken},
        }
        for tier in range(1, MAX_TIER + 1)
    ]
    return {
        "season_id": season_id,
        "ends_at": end.replace(tzinfo=timezone.utc).isoformat(),
        "seasonal_points": points,
        "unlocked_tier": top,
        "premium_unlocked": premium,
        "premium_price_coins": PREMIUM_PRICE_COINS,
        "tiers": tiers,
    }
