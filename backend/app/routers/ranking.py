from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User
from app.schemas import RankingEntry
from app.services.scoring import full_ranking

router = APIRouter(tags=["ranking"])


@router.get("/ranking", response_model=list[RankingEntry])
def get_ranking(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return [
        RankingEntry(
            position=i,
            owner_type=row.owner_type,
            name=row.name,
            photo_url=row.photo_url,
            total_score=row.score,
            territories_count=row.territories,
            level=row.level,
        )
        for i, row in enumerate(full_ranking(db), start=1)
    ]  # RF12 / RN11 — jogadores e equipes juntos
