"""Unicidade de apelido insensível a caixa e espaços (RN02)."""

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import User


def normalize_username(value: str) -> str:
    return value.strip()


def username_taken(
    db: Session, username: str, exclude_id: str | None = None
) -> bool:
    lowered = normalize_username(username).lower()
    query = db.query(User).filter(func.lower(User.username) == lowered)
    if exclude_id is not None:
        query = query.filter(User.id != exclude_id)
    return query.first() is not None
