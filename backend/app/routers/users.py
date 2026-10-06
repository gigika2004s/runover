from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, hash_password
from app.models import (
    ClaimReceipt,
    ConquestMark,
    LocationPing,
    Notification,
    OAuthIdentity,
    PasswordReset,
    PasswordResetToken,
    Run,
    ScoreEvent,
    Team,
    TeamMember,
    TerritoryOwnership,
    User,
)
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


def _training_days_list(user: User) -> list[str]:
    return [d for d in (user.training_days or "").split(",") if d]


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
        distance_units=current_user.distance_units or "km",
        weekly_frequency=current_user.weekly_frequency,
        training_days=_training_days_list(current_user),
        activity_level=current_user.activity_level,
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
    if "photo_url" in data.model_fields_set:
        current_user.photo_url = data.photo_url
    if data.password:
        current_user.password_hash = hash_password(data.password)
        db.query(PasswordReset).filter(PasswordReset.user_id == current_user.id).delete()
    if data.is_public is not None:
        current_user.is_public = data.is_public  # RF05 — configuração de privacidade
    if data.distance_units is not None:
        current_user.distance_units = data.distance_units
    if "weekly_frequency" in data.model_fields_set:
        current_user.weekly_frequency = data.weekly_frequency
    if "training_days" in data.model_fields_set:
        current_user.training_days = ",".join(data.training_days or [])
    if "activity_level" in data.model_fields_set:
        current_user.activity_level = data.activity_level

    db.commit()
    db.refresh(current_user)
    return get_my_profile(db, current_user)


@router.delete("/users/me", status_code=204)
def delete_my_account(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Exclusão de conta (LGPD): apaga dados pessoais e libera territórios.

    Territórios voltam a ficar livres (dono anulado, histórico preservado
    sem titular). Equipes são compartilhadas: saia da equipe antes — mesmo
    sendo criador — para não deixar time órfão.
    """
    uid = current_user.id
    in_team = (
        db.query(TeamMember).filter(TeamMember.user_id == uid).first()
        or db.query(Team).filter(Team.creator_id == uid).first()
    )
    if in_team:
        raise HTTPException(
            409, "Saia da sua equipe antes de excluir a conta."
        )
    db.query(TerritoryOwnership).filter(
        TerritoryOwnership.owner_user_id == uid
    ).update({TerritoryOwnership.owner_user_id: None})
    db.query(ConquestMark).filter(
        ConquestMark.owner_user_id == uid
    ).update({ConquestMark.owner_user_id: None})
    for model in (
        Run,
        ClaimReceipt,
        ScoreEvent,
        Notification,
        LocationPing,
        PasswordReset,
        PasswordResetToken,
        OAuthIdentity,
    ):
        db.query(model).filter(model.user_id == uid).delete(
            synchronize_session=False
        )
    db.delete(current_user)
    db.commit()
    return None


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
