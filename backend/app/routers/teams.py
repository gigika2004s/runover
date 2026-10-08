from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db, lock_mutations
from app.core.security import get_current_user
from app.models import (
    ConquestMark,
    LocationPing,
    Run,
    ScoreEvent,
    Team,
    TeamAdmin,
    TeamJoinRequest,
    TeamMember,
    TerritoryOwnership,
    User,
)
from app.schemas import (
    TeamAdminRequest,
    TeamCreateRequest,
    TeamDetail,
    TeamJoinRequestEntry,
    TeamMemberInfo,
    TeamSummary,
    TeamUpdateRequest,
)
from app.services.notifications import notify
from app.services.scoring import (
    current_team_territory_ids,
    level_info,
    total_team_score,
    user_team,
)

router = APIRouter(prefix="/teams", tags=["equipes"])


def _is_owner(team: Team, user_id: str) -> bool:
    return team.creator_id == user_id


def _is_admin(db: Session, team: Team, user_id: str) -> bool:
    return _is_owner(team, user_id) or db.query(TeamAdmin).filter(
        TeamAdmin.team_id == team.id, TeamAdmin.user_id == user_id
    ).first() is not None


def _admin_ids(db: Session, team: Team) -> list[str]:
    ids = [a.user_id for a in db.query(TeamAdmin).filter(TeamAdmin.team_id == team.id).all()]
    return [team.creator_id] + [i for i in ids if i != team.creator_id]


def transfer_ownership(db: Session, team: Team, exclude_user_id: str | None = None) -> str | None:
    """Passa o dono ao membro mais antigo (por entrada). Sem membros, None.

    O novo dono vira admin automaticamente via `_is_admin` (dono implica
    admin), sem precisar de linha extra em TeamAdmin.
    """
    candidates = sorted(
        (m for m in team.members if m.user_id != exclude_user_id),
        key=lambda m: (m.joined_at, m.user_id),
    )
    if not candidates:
        return None
    team.creator_id = candidates[0].user_id
    db.flush()
    return team.creator_id


def _dissolve_team(db: Session, team: Team) -> None:
    """Dissolve com a mesma limpeza do disband: libera territórios e apaga vínculos."""
    for member in list(team.members):
        db.delete(member)
    db.query(TeamAdmin).filter(TeamAdmin.team_id == team.id).delete(
        synchronize_session=False
    )
    db.query(TeamJoinRequest).filter(
        TeamJoinRequest.team_id == team.id
    ).delete(synchronize_session=False)
    db.query(TerritoryOwnership).filter(
        TerritoryOwnership.owner_team_id == team.id
    ).update({TerritoryOwnership.owner_team_id: None})
    db.query(ConquestMark).filter(
        ConquestMark.owner_team_id == team.id
    ).update({ConquestMark.owner_team_id: None})
    db.query(ScoreEvent).filter(ScoreEvent.team_id == team.id).update(
        {ScoreEvent.team_id: None}
    )
    db.query(Run).filter(Run.team_id == team.id).update(
        {Run.team_id: None}, synchronize_session=False
    )
    db.delete(team)


ONLINE_WINDOW = timedelta(minutes=15)


def _online_count(db: Session, member_ids: list[str]) -> int:
    """Membros com ping de localização dentro da janela (tempo real)."""
    if not member_ids:
        return 0
    # Colunas DateTime sem timezone: compara em UTC naive (padrão de runs.py).
    cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - ONLINE_WINDOW
    return (
        db.query(LocationPing.user_id)
        .filter(
            LocationPing.user_id.in_(member_ids),
            LocationPing.recorded_at >= cutoff,
        )
        .distinct()
        .count()
    )


def _to_detail(db: Session, team: Team, viewer_id: str | None = None) -> TeamDetail:
    members = db.query(TeamMember).filter(TeamMember.team_id == team.id).all()
    admin_ids = set(_admin_ids(db, team))
    score = total_team_score(db, team.id)
    level, progress, to_next = level_info(score)
    pending: list[TeamJoinRequestEntry] = []
    my_request: str | None = None
    if viewer_id is not None:
        if _is_admin(db, team, viewer_id):
            pending = [
                TeamJoinRequestEntry(
                    id=r.id,
                    username=r.user.username,
                    photo_url=r.user.photo_url,
                    created_at=r.created_at,
                )
                for r in db.query(TeamJoinRequest).filter(
                    TeamJoinRequest.team_id == team.id,
                    TeamJoinRequest.status == "pending",
                ).order_by(TeamJoinRequest.created_at).all()
            ]
        else:
            mine = db.query(TeamJoinRequest).filter(
                TeamJoinRequest.team_id == team.id,
                TeamJoinRequest.user_id == viewer_id,
                TeamJoinRequest.status == "pending",
            ).first()
            my_request = "pending" if mine else None
    return TeamDetail(
        id=team.id,
        name=team.name,
        photo_url=team.photo_url,
        creator_username=team.creator.username,
        member_count=len(members),
        members=[
            TeamMemberInfo(
                username=m.user.username,
                photo_url=m.user.photo_url,
                is_admin=m.user_id in admin_ids,
            )
            for m in members
        ],
        total_score=score,
        territories_count=len(current_team_territory_ids(db, team.id)),
        level=level,
        level_progress=progress,
        points_to_next_level=to_next,
        is_owner=viewer_id is not None and _is_owner(team, viewer_id),
        is_admin=viewer_id is not None and _is_admin(db, team, viewer_id),
        my_request=my_request,
        pending_requests=pending,
        online_count=_online_count(db, [m.user_id for m in members]),
    )


@router.get("", response_model=list[TeamSummary])
def list_teams(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    teams = db.query(Team).all()
    return [
        TeamSummary(
            id=t.id,
            name=t.name,
            photo_url=t.photo_url,
            creator_username=t.creator.username,
            member_count=db.query(TeamMember).filter(TeamMember.team_id == t.id).count(),
        )
        for t in teams
    ]  # UC12b — "Pesquisa equipes disponíveis"


@router.post("", response_model=TeamDetail, status_code=201)
def create_team(
    data: TeamCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    lock_mutations(db)
    if user_team(db, current_user.id):
        raise HTTPException(400, "Você já faz parte de uma equipe. Saia dela antes de criar outra.")
    if db.query(Team).filter(Team.name == data.name).first():
        raise HTTPException(400, "Já existe uma equipe com esse nome.")

    team = Team(name=data.name, creator_id=current_user.id)
    db.add(team)
    db.flush()
    db.add(TeamMember(team_id=team.id, user_id=current_user.id))  # UC12a — "Define usuário como líder"
    db.commit()
    db.refresh(team)
    return _to_detail(db, team, current_user.id)


@router.get("/mine", response_model=TeamDetail)
def get_my_team(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    team = user_team(db, current_user.id)
    if not team:
        raise HTTPException(404, "Você ainda não participa de uma equipe.")
    return _to_detail(db, team, current_user.id)


@router.get("/{team_id}", response_model=TeamDetail)
def get_team(team_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")
    return _to_detail(db, team, current_user.id)


@router.post("/{team_id}/join", response_model=TeamDetail, status_code=202)
def join_team(team_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Pede para entrar: dono/admins aprovam depois."""
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")  # UC12b — "[não encontrada]"
    lock_mutations(db)
    if user_team(db, current_user.id):
        raise HTTPException(400, "Você já faz parte de uma equipe. Saia dela antes de entrar em outra.")
    existing = db.query(TeamJoinRequest).filter(
        TeamJoinRequest.team_id == team.id,
        TeamJoinRequest.user_id == current_user.id,
        TeamJoinRequest.status == "pending",
    ).first()
    if existing:
        raise HTTPException(409, "Seu pedido já está aguardando aprovação.")

    db.add(TeamJoinRequest(team_id=team.id, user_id=current_user.id))
    try:
        db.flush()
    except IntegrityError:
        raise HTTPException(409, "Seu pedido já está aguardando aprovação.")
    for admin_id in _admin_ids(db, team):
        notify(db, admin_id, f"@{current_user.username} pediu para entrar em {team.name}.", "equipe")
    db.commit()
    db.refresh(team)
    return _to_detail(db, team, current_user.id)


def _require_admin(db: Session, team_id: str, user: User) -> Team:
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")
    if not _is_admin(db, team, user.id):
        raise HTTPException(403, "Só o dono ou admins decidem pedidos.")
    return team


@router.get("/{team_id}/requests", response_model=list[TeamJoinRequestEntry])
def list_join_requests(team_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    team = _require_admin(db, team_id, current_user)
    return [
        TeamJoinRequestEntry(
            id=r.id,
            username=r.user.username,
            photo_url=r.user.photo_url,
            created_at=r.created_at,
        )
        for r in db.query(TeamJoinRequest).filter(
            TeamJoinRequest.team_id == team.id,
            TeamJoinRequest.status == "pending",
        ).order_by(TeamJoinRequest.created_at).all()
    ]


def _decide_request(db: Session, team: Team, request_id: str, approve: bool) -> TeamJoinRequest:
    req = db.query(TeamJoinRequest).filter(
        TeamJoinRequest.id == request_id,
        TeamJoinRequest.team_id == team.id,
        TeamJoinRequest.status == "pending",
    ).first()
    if not req:
        raise HTTPException(404, "Pedido não encontrado ou já decidido.")
    if approve:
        if user_team(db, req.user_id):
            raise HTTPException(409, "O jogador já entrou em outra equipe.")
        db.add(TeamMember(team_id=team.id, user_id=req.user_id))
        req.status = "approved"
        # Pedidos do mesmo jogador em outras equipes caducam juntos.
        db.query(TeamJoinRequest).filter(
            TeamJoinRequest.user_id == req.user_id,
            TeamJoinRequest.status == "pending",
            TeamJoinRequest.id != req.id,
        ).delete(synchronize_session=False)
        notify(db, req.user_id, f"Bem-vindo a {team.name}! Seu pedido foi aceito.", "equipe")
    else:
        req.status = "rejected"
        notify(db, req.user_id, f"Seu pedido para {team.name} foi recusado.", "equipe")
    req.decided_at = datetime.now(timezone.utc)
    return req


@router.post("/{team_id}/requests/{request_id}/approve", response_model=TeamDetail)
def approve_request(team_id: str, request_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    lock_mutations(db)
    team = _require_admin(db, team_id, current_user)
    _decide_request(db, team, request_id, True)
    db.commit()
    return _to_detail(db, team, current_user.id)


@router.post("/{team_id}/requests/{request_id}/reject", response_model=TeamDetail)
def reject_request(team_id: str, request_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    lock_mutations(db)
    team = _require_admin(db, team_id, current_user)
    _decide_request(db, team, request_id, False)
    db.commit()
    return _to_detail(db, team, current_user.id)


@router.post("/{team_id}/admins", response_model=TeamDetail)
def promote_admin(team_id: str, data: TeamAdminRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Só o dono promove."""
    lock_mutations(db)
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")
    if not _is_owner(team, current_user.id):
        raise HTTPException(403, "Só o dono escolhe admins.")
    target = db.query(User).filter(User.username == data.username).first()
    if not target:
        raise HTTPException(404, "Usuário não encontrado.")
    if not db.query(TeamMember).filter(
        TeamMember.team_id == team.id, TeamMember.user_id == target.id
    ).first():
        raise HTTPException(400, "Só membros podem virar admin.")
    if not _is_admin(db, team, target.id):
        db.add(TeamAdmin(team_id=team.id, user_id=target.id, granted_by=current_user.id))
    db.commit()
    return _to_detail(db, team, current_user.id)


@router.delete("/{team_id}/admins/{username}", response_model=TeamDetail)
def demote_admin(team_id: str, username: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    lock_mutations(db)
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")
    if not _is_owner(team, current_user.id):
        raise HTTPException(403, "Só o dono remove admins.")
    if username == team.creator.username:
        raise HTTPException(400, "O dono não pode deixar de ser dono.")
    row = db.query(TeamAdmin).join(User, TeamAdmin.user_id == User.id).filter(
        TeamAdmin.team_id == team.id, User.username == username
    ).first()
    if row:
        db.delete(row)
    db.commit()
    return _to_detail(db, team, current_user.id)


@router.patch("/{team_id}", response_model=TeamDetail)
def update_team(
    team_id: str,
    data: TeamUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Foto e nome: dono e admins. Nome continua único."""
    lock_mutations(db)
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")
    if not _is_admin(db, team, current_user.id):
        raise HTTPException(403, "Só o dono ou admins editam a equipe.")
    if data.name and data.name != team.name:
        if db.query(Team).filter(Team.name == data.name).first():
            raise HTTPException(400, "Já existe uma equipe com esse nome.")
        team.name = data.name
    if "photo_url" in data.model_fields_set:
        team.photo_url = data.photo_url
    db.commit()
    return _to_detail(db, team, current_user.id)


@router.delete("/{team_id}", status_code=204)
def disband_team(
    team_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    """Dissolve a equipe. Só o dono; avisa os membros."""
    lock_mutations(db)
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")
    if not _is_owner(team, current_user.id):
        raise HTTPException(403, "Só o dono dissolve a equipe.")
    member_ids = [
        m.user_id
        for m in db.query(TeamMember).filter(TeamMember.team_id == team.id).all()
    ]
    db.query(TeamMember).filter(TeamMember.team_id == team.id).delete(
        synchronize_session=False
    )
    db.query(TeamAdmin).filter(TeamAdmin.team_id == team.id).delete(
        synchronize_session=False
    )
    db.query(TeamJoinRequest).filter(
        TeamJoinRequest.team_id == team.id
    ).delete(synchronize_session=False)
    db.query(TerritoryOwnership).filter(
        TerritoryOwnership.owner_team_id == team.id
    ).update({TerritoryOwnership.owner_team_id: None})
    db.query(ConquestMark).filter(
        ConquestMark.owner_team_id == team.id
    ).update({ConquestMark.owner_team_id: None})
    db.query(ScoreEvent).filter(ScoreEvent.team_id == team.id).update(
        {ScoreEvent.team_id: None}
    )
    db.query(Run).filter(Run.team_id == team.id).update({Run.team_id: None})
    for uid in member_ids:
        if uid != current_user.id:
            notify(db, uid, f"A equipe {team.name} foi dissolvida.", "equipe")
    db.delete(team)
    db.commit()
    return None


@router.post("/leave", status_code=204)
def leave_team(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Sair nunca deixa time órfão: o dono transfere ao membro mais antigo.

    Dono sozinho dissolve o time (equivale a dissolver antes de sair).
    """
    lock_mutations(db)
    membership = db.query(TeamMember).filter(TeamMember.user_id == current_user.id).first()
    if not membership:
        raise HTTPException(400, "Você não participa de nenhuma equipe.")
    team = db.get(Team, membership.team_id)
    if team is not None and team.creator_id == current_user.id:
        others = [m for m in team.members if m.user_id != current_user.id]
        if others:
            transfer_ownership(db, team, exclude_user_id=current_user.id)
        else:
            _dissolve_team(db, team)
            db.commit()
            return None
    db.delete(membership)
    db.query(TeamAdmin).filter(TeamAdmin.user_id == current_user.id).delete(synchronize_session=False)
    db.commit()
