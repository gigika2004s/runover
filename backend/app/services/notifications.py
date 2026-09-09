from sqlalchemy.orm import Session

from app.models import Notification


def notify(db: Session, user_id: str, message: str, type_: str) -> None:
    """UC "Receber Notificação" — "Gera a notificação" / "Envia notificação ao usuário"."""
    db.add(Notification(user_id=user_id, message=message, type=type_))
