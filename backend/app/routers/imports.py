"""Importação de atividades de serviços externos (Nike Run Club)."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User
from app.routers.runs import create_run
from app.schemas import RunRequest
from app.services.nrc import (
    NikeApiError,
    activity_to_run_payload,
    fetch_activity_details,
    fetch_activities,
)

router = APIRouter(prefix="/import", tags=["importação"])


class NrcImportRequest(BaseModel):
    token: str = Field(min_length=10, max_length=8192)


@router.post("/nrc/runs")
def import_nrc_runs(
    body: NrcImportRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Importa corridas do Nike Run Club usando o token de acesso do usuário.

    Cada corrida passa pelas mesmas validações de POST /runs: corridas com
    mais de 7 dias ou sem dados de GPS ficam de fora e o motivo vem no
    resumo. A importação é idempotente — reimportar a mesma atividade não
    duplica a corrida."""
    try:
        activity_ids = fetch_activities(body.token)
    except NikeApiError as exc:
        raise HTTPException(401, str(exc)) from exc

    imported: list[dict] = []
    skipped: list[dict] = []
    for activity_id in activity_ids:
        try:
            activity = fetch_activity_details(body.token, activity_id)
        except NikeApiError as exc:
            skipped.append({"activity_id": activity_id, "reason": str(exc)})
            continue
        payload = activity_to_run_payload(activity)
        if payload is None:
            skipped.append({"activity_id": activity_id, "reason": "Atividade sem dados de GPS."})
            continue
        try:
            imported.append(create_run(db, user, RunRequest.model_validate(payload)))
        except HTTPException as exc:
            skipped.append({"activity_id": activity_id, "reason": str(exc.detail)})
    return {
        "imported_count": len(imported),
        "skipped_count": len(skipped),
        "imported": imported,
        "skipped": skipped,
    }
