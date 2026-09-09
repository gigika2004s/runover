from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, hash_password
from app.models import ScoreEvent, User
from app.schemas import HistoryEntry, ProfileUpdateRequest, UserProfile, UserPublic
from app.services.scoring import (
    current_owner_territory_ids,
    level_info,
    rank_position,
    total_score,
    user_team,
)

router = APIRouter(tags=["usuários"])


def _to_public(db: Session, user: User) -> UserPublic:
    team = user_team(db, user.id)
    score = total_score(db, user.id)
    level, progress, to_next = level_info(score)
    return UserPublic(
        username=user.username,
        photo_url=user.photo_url,
        total_score=score,
        territories_count=len(current_owner_territory_ids(db, user.id)),
        rank_position=rank_position(db, user.id),
        team_name=team.name if team else None,
        level=level,
        level_progress=progress,
        points_to_next_level=to_next,
    )


@router.get("/users/me", response_model=UserProfile)
def get_my_profile(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    public = _to_public(db, current_user)
    return UserProfile(
        **public.model_dump(),
        id=current_user.id,
        full_name=current_user.full_name,
        email=current_user.email,
        created_at=current_user.created_at,
        is_public=current_user.is_public,
        play_seconds=current_user.play_seconds,
    )


@router.patch("/users/me", response_model=UserProfile)
def update_my_profile(
    data: ProfileUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if data.username and data.username != current_user.username:
        if db.query(User).filter(User.username == data.username).first():
            raise HTTPException(400, "Esse nome de usuário já está em uso.")
        current_user.username = data.username
    if data.full_name:
        current_user.full_name = data.full_name
    if data.photo_url is not None:
        current_user.photo_url = data.photo_url
    if data.password:
        if len(data.password) < 8 or not any(c.isdigit() for c in data.password):
            raise HTTPException(400, "A senha deve ter no mínimo 8 caracteres, incluindo letras e números.")
        current_user.password_hash = hash_password(data.password)
    if data.is_public is not None:
        current_user.is_public = data.is_public  # RF05 — configuração de privacidade

    db.commit()
    db.refresh(current_user)
    return get_my_profile(db, current_user)


@router.get("/users/{username}", response_model=UserPublic)
def get_public_profile(
    username: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(404, "Usuário não encontrado.")
    if not user.is_public and user.id != current_user.id:
        # RF05 / RN13 — perfil privado: só o próprio dono enxerga
        raise HTTPException(403, "Este perfil é privado.")
    return _to_public(db, user)  # RF17 — só dados públicos


@router.get("/users/me/history", response_model=list[HistoryEntry])
def get_my_history(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    events = (
        db.query(ScoreEvent)
        .filter(ScoreEvent.user_id == current_user.id)
        .order_by(ScoreEvent.created_at.desc())
        .all()
    )
    return [
        HistoryEntry(
            territory_name=e.territory.name if e.territory else None,
            delta=e.delta,
            reason=e.reason,
            created_at=e.created_at,
        )
        for e in events
    ]
