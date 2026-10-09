from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db, lock_mutations
from app.core.security import get_current_user
from app.models import User, UserCosmetic, UserFavorite
from app.schemas import CosmeticItem, ShopState

router = APIRouter(prefix="/shop", tags=["loja"])

CATALOG = (
    CosmeticItem(id="badge-route", name="Explorador de rotas", kind="badge",
                 description="Uma insignia para quem não para de correr.",
                 price=100, rarity="comum"),
    CosmeticItem(id="frame-territory", name="Moldura território", kind="avatar_frame",
                 description="Moldura inspirada nas áreas conquistadas.",
                 price=250, rarity="raro"),
    CosmeticItem(id="effect-sunset", name="Efeito pôr do sol", kind="profile_effect",
                 description="Um brilho de rota para o seu perfil.",
                 price=400, rarity="épico"),
    CosmeticItem(id="name-route", name="Nome de rota", kind="name_style",
                 description="Destaque seu nome com a cor da rota.",
                 price=180, rarity="comum"),
)


def _find(item_id: str) -> CosmeticItem:
    item = next((item for item in CATALOG if item.id == item_id), None)
    if item is None:
        raise HTTPException(404, "Item não encontrado.")
    return item


def _state(db: Session, user: User) -> ShopState:
    owned = [item_id for (item_id,) in db.query(UserCosmetic.item_id)
             .filter(UserCosmetic.user_id == user.id).all()]
    favorites = [item_id for (item_id,) in db.query(UserFavorite.item_id)
                 .filter(UserFavorite.user_id == user.id).all()]
    equipped = [item for item in (user.equipped_cosmetics or "").split(",") if item]
    return ShopState(balance=user.coin_balance, items=list(CATALOG), owned=owned,
                     favorites=favorites, equipped=equipped)


@router.get("", response_model=ShopState)
def get_shop(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return _state(db, user)


@router.post("/{item_id}/purchase", response_model=ShopState)
def purchase(item_id: str, db: Session = Depends(get_db),
             user: User = Depends(get_current_user)):
    item = _find(item_id)
    if db.query(UserCosmetic).filter_by(user_id=user.id, item_id=item_id).first():
        raise HTTPException(409, "Você já possui este item.")
    if user.coin_balance < item.price:
        raise HTTPException(400, "Moedas insuficientes.")
    lock_mutations(db)
    user.coin_balance -= item.price
    db.add(UserCosmetic(user_id=user.id, item_id=item_id))
    db.commit()
    db.refresh(user)
    return _state(db, user)


@router.post("/{item_id}/favorite", response_model=ShopState)
def toggle_favorite(item_id: str, db: Session = Depends(get_db),
                    user: User = Depends(get_current_user)):
    _find(item_id)
    favorite = db.query(UserFavorite).filter_by(user_id=user.id, item_id=item_id).first()
    if favorite:
        db.delete(favorite)
    else:
        db.add(UserFavorite(user_id=user.id, item_id=item_id))
    db.commit()
    return _state(db, user)


@router.post("/{item_id}/equip", response_model=ShopState)
def equip(item_id: str, db: Session = Depends(get_db),
          user: User = Depends(get_current_user)):
    item = _find(item_id)
    if not db.query(UserCosmetic).filter_by(user_id=user.id, item_id=item_id).first():
        raise HTTPException(403, "Compre este item antes de equipá-lo.")
    equipped = [value for value in (user.equipped_cosmetics or "").split(",") if value]
    equipped = [value for value in equipped if not value.startswith(f"{item.kind}:")]
    equipped.append(f"{item.kind}:{item.id}")
    user.equipped_cosmetics = ",".join(equipped)
    db.commit()
    db.refresh(user)
    return _state(db, user)
