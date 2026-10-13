"""Pass Runover: temporada mensal, trilhas gratuita e premium."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db, lock_mutations
from app.core.security import get_current_user
from app.models import PassClaim, PassPremium, User, UserItem
from app.schemas import PassClaimRequest, PassStatus
from app.services.coins import credit, debit
from app.services.pass_runover import (
    PREMIUM_PRICE_COINS,
    current_season,
    is_premium,
    pass_status,
    premium_reward,
    free_reward,
    tier_threshold,
    unlocked_tier,
    seasonal_points,
)
from app.services.shop import get_item

router = APIRouter(prefix="/pass", tags=["passe"])


@router.get("", response_model=PassStatus)
def get_pass(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return pass_status(db, current_user.id)


@router.post("/premium", response_model=PassStatus)
def unlock_premium(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    """Desbloqueia a trilha premium da temporada com moedas do jogo."""
    lock_mutations(db)
    db.refresh(current_user)
    season_id = current_season()
    if is_premium(db, current_user.id, season_id):
        raise HTTPException(409, "A trilha premium já está desbloqueada.")
    debit(db, current_user, PREMIUM_PRICE_COINS, f"passe:{season_id}")
    db.add(PassPremium(user_id=current_user.id, season_id=season_id))
    try:
        db.flush()
    except IntegrityError:
        raise HTTPException(409, "A trilha premium já está desbloqueada.")
    db.commit()
    db.refresh(current_user)
    return pass_status(db, current_user.id)


@router.post("/claim", response_model=PassStatus)
def claim_reward(
    data: PassClaimRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Resgata a recompensa de um tier liberado (moedas + item exclusivo)."""
    lock_mutations(db)
    db.refresh(current_user)
    season_id = current_season()
    top = unlocked_tier(seasonal_points(db, current_user.id, season_id))
    if data.tier > top:
        raise HTTPException(
            400,
            f"Tier {data.tier} ainda bloqueado "
            f"(faltam {tier_threshold(data.tier) - seasonal_points(db, current_user.id, season_id)} pts).",
        )
    if data.track == "premium" and not is_premium(db, current_user.id, season_id):
        raise HTTPException(403, "Desbloqueie a trilha premium para resgatar.")
    existing = (
        db.query(PassClaim)
        .filter(
            PassClaim.user_id == current_user.id,
            PassClaim.season_id == season_id,
            PassClaim.tier == data.tier,
            PassClaim.track == data.track,
        )
        .first()
    )
    if existing:
        raise HTTPException(409, "Recompensa já resgatada.")
    reward = premium_reward(data.tier) if data.track == "premium" else free_reward(data.tier)
    if reward["coins"] > 0:
        credit(db, current_user, reward["coins"], f"passe:{season_id}:t{data.tier}:{data.track}")
    item_id = reward["item_id"]
    if item_id is not None:
        if get_item(item_id) is None:
            raise HTTPException(500, "Recompensa inválida.")
        already = (
            db.query(UserItem)
            .filter(UserItem.user_id == current_user.id, UserItem.item_id == item_id)
            .first()
        )
        if already is None:
            db.add(UserItem(user_id=current_user.id, item_id=item_id))
    db.add(
        PassClaim(
            user_id=current_user.id,
            season_id=season_id,
            tier=data.tier,
            track=data.track,
        )
    )
    try:
        db.flush()
    except IntegrityError:
        raise HTTPException(409, "Recompensa já resgatada.")
    db.commit()
    db.refresh(current_user)
    return pass_status(db, current_user.id)
