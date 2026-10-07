from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import PresencePing, User

router = APIRouter(prefix="/presence", tags=["presença"])


@router.post("", status_code=204)
def ping_presence(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Sinal de app aberto — alimenta o 'online' da equipe sem usar GPS."""
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    row = db.get(PresencePing, current_user.id)
    if row is None:
        db.add(PresencePing(user_id=current_user.id, updated_at=now))
    else:
        row.updated_at = now
    db.commit()
