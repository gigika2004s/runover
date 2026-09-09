from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import Team, TeamMember, User
from app.schemas import TeamCreateRequest, TeamDetail, TeamMemberInfo, TeamSummary
from app.services.scoring import (
    current_team_territory_ids,
    level_info,
    total_team_score,
    user_team,
)

router = APIRouter(prefix="/teams", tags=["equipes"])


def _to_detail(db: Session, team: Team) -> TeamDetail:
    members = db.query(TeamMember).filter(TeamMember.team_id == team.id).all()
    score = total_team_score(db, team.id)
    level, progress, to_next = level_info(score)
    return TeamDetail(
        id=team.id,
        name=team.name,
        creator_username=team.creator.username,
        member_count=len(members),
        members=[TeamMemberInfo(username=m.user.username, photo_url=m.user.photo_url) for m in members],
        total_score=score,
        territories_count=len(current_team_territory_ids(db, team.id)),
        level=level,
        level_progress=progress,
        points_to_next_level=to_next,
    )


@router.get("", response_model=list[TeamSummary])
def list_teams(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    teams = db.query(Team).all()
    return [
        TeamSummary(
            id=t.id,
            name=t.name,
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
    return _to_detail(db, team)


@router.get("/mine", response_model=TeamDetail)
def get_my_team(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    team = user_team(db, current_user.id)
    if not team:
        raise HTTPException(404, "Você ainda não participa de uma equipe.")
    return _to_detail(db, team)


@router.get("/{team_id}", response_model=TeamDetail)
def get_team(team_id: str, db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")
    return _to_detail(db, team)


@router.post("/{team_id}/join", response_model=TeamDetail)
def join_team(team_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    team = db.get(Team, team_id)
    if not team:
        raise HTTPException(404, "Equipe não encontrada.")  # UC12b — "[não encontrada]"
    if user_team(db, current_user.id):
        raise HTTPException(400, "Você já faz parte de uma equipe. Saia dela antes de entrar em outra.")

    db.add(TeamMember(team_id=team.id, user_id=current_user.id))  # UC12b — "Adiciona usuário à equipe"
    db.commit()
    return _to_detail(db, team)


@router.post("/leave", status_code=204)
def leave_team(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    membership = db.query(TeamMember).filter(TeamMember.user_id == current_user.id).first()
    if not membership:
        raise HTTPException(400, "Você não participa de nenhuma equipe.")
    db.delete(membership)
    db.commit()
