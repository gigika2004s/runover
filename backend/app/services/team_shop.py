"""Cofre da loja da equipe: soma dos pontos dos integrantes menos o já gasto.

Ninguém perde nível, posição no ranking ou moedas ao comprar para a equipe:
o gasto acumula em `Team.spent_points` e o saldo é sempre recalculado dos
membros atuais. Quem entra soma; quem sai deixa de somar (o já gasto fica).
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import Team, TeamMember
from app.services.scoring import total_score


def members_points(db: Session, team_id: str) -> int:
    """Soma do `total_score` (pontos) de cada integrante atual."""
    member_ids = [
        m.user_id
        for m in db.query(TeamMember).filter(TeamMember.team_id == team_id).all()
    ]
    return sum(total_score(db, uid) for uid in member_ids)


def team_balance(db: Session, team: Team) -> tuple[int, int]:
    """(saldo gastável, pontos somados). O saldo nunca é negativo."""
    earned = members_points(db, team.id)
    balance = max(0, earned - (team.spent_points or 0))
    return balance, earned
