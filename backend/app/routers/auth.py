import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models import PasswordResetToken, User
from app.services.email import EmailDeliveryError, send_password_reset_email
from app.schemas import (
    ForgotPasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)

router = APIRouter(prefix="/auth", tags=["autenticação"])

logger = logging.getLogger(__name__)


def _token_digest(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.username == data.username).first():
        raise HTTPException(400, "Esse nome de usuário já está em uso.")  # RN02
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(400, "Já existe uma conta com esse e-mail.")

    user = User(
        full_name=data.full_name,
        username=data.username,
        email=data.email,
        password_hash=hash_password(data.password),
        photo_url=data.photo_url or None,  # RF01 — foto de perfil (opcional)
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.id))


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == data.email).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-mail ou senha incorretos.")
    return TokenResponse(access_token=create_access_token(user.id))


@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    generic_response = {"message": "Se esse e-mail estiver cadastrado, enviaremos instruções."}
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        return generic_response

    now = datetime.now(timezone.utc)
    cooldown_start = now - timedelta(seconds=settings.password_reset_cooldown_seconds)
    recent = db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.created_at >= cooldown_start,
    ).first()
    if recent:
        return generic_response

    code = f"{secrets.randbelow(1_000_000_000_000):012d}"
    db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.used_at.is_(None),
    ).delete(synchronize_session=False)
    db.add(PasswordResetToken(
        user_id=user.id,
        token_hash=_token_digest(code),
        expires_at=now + timedelta(minutes=settings.password_reset_expire_minutes),
    ))
    db.commit()

    try:
        send_password_reset_email(user.email, user.username, code)
    except EmailDeliveryError:
        # Keep the same public response for existing and unknown addresses.
        logger.exception("Password reset email delivery failed")
    return generic_response


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    reset = db.query(PasswordResetToken).join(User).filter(
        User.email == data.email,
        PasswordResetToken.token_hash == _token_digest(data.reset_code),
        PasswordResetToken.used_at.is_(None),
    ).with_for_update().first()
    if not reset:
        active_reset = db.query(PasswordResetToken).join(User).filter(
            User.email == data.email,
            PasswordResetToken.used_at.is_(None),
        ).order_by(PasswordResetToken.created_at.desc()).with_for_update().first()
        if active_reset:
            active_reset.attempts += 1
            if active_reset.attempts >= 5:
                active_reset.used_at = datetime.now(timezone.utc)
            db.commit()
        raise HTTPException(400, "Token de redefinição inválido ou já utilizado.")

    expires_at = reset.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= datetime.now(timezone.utc):
        reset.used_at = datetime.now(timezone.utc)
        db.commit()
        raise HTTPException(400, "Código de redefinição expirado.")

    user = db.get(User, reset.user_id)
    if not user:
        raise HTTPException(400, "Token de redefinição inválido ou já utilizado.")

    user.password_hash = hash_password(data.new_password)
    reset.used_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Senha redefinida com sucesso."}
