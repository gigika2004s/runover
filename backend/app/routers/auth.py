import hashlib
import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db, lock_mutations
from app.core.security import create_access_token, hash_password, verify_password
from app.models import AuthAttempt, PasswordReset, User
from app.schemas import ForgotPasswordRequest, LoginRequest, RegisterRequest, ResetPasswordRequest, TokenResponse
from app.services.mail import send_reset_email

router = APIRouter(prefix="/auth", tags=["autenticação"])
_GENERIC_RESET = {"message": "Se esse e-mail estiver cadastrado, enviaremos um código de recuperação. Verifique também o spam."}


def throttle(db, key, limit, minutes=15):
    now = datetime.utcnow()
    digest = hashlib.sha256(key.encode()).hexdigest()
    lock_mutations(db)
    db.query(AuthAttempt).filter(AuthAttempt.window_start < now - timedelta(days=1)).delete()
    row = db.get(AuthAttempt, digest)
    if row is None:
        row = AuthAttempt(key=digest, count=0, window_start=now)
        db.add(row)
    elif row.window_start <= now - timedelta(minutes=minutes):
        row.window_start, row.count = now, 0
    row.count += 1
    allowed = row.count <= limit
    db.commit()
    return allowed


def client_key(request):
    # Only use the trusted ASGI client, never arbitrary X-Forwarded-For headers.
    return request.client.host if request.client else "unknown"


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, request: Request, db: Session = Depends(get_db)):
    if not throttle(db, "register:" + client_key(request), 20):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    lock_mutations(db)
    if db.query(User).filter(User.username == data.username).first():
        raise HTTPException(400, "Esse nome de usuário já está em uso.")
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(400, "Já existe uma conta com esse e-mail.")
    user = User(full_name=data.full_name, username=data.username, email=data.email,
                password_hash=hash_password(data.password), photo_url=data.photo_url or None)
    db.add(user)
    db.commit()
    return TokenResponse(access_token=create_access_token(user.id, user.password_hash))


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, request: Request, db: Session = Depends(get_db)):
    if not throttle(db, "login-ip:" + client_key(request), 60) or not throttle(db, "login:" + data.email, 15):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    user = db.query(User).filter(User.email == data.email).first()
    if len(data.password.encode()) > 72 or not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(401, "E-mail ou senha incorretos.")
    return TokenResponse(access_token=create_access_token(user.id, user.password_hash))


@router.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest, request: Request, tasks: BackgroundTasks, db: Session = Depends(get_db)):
    if not throttle(db, "reset-ip:" + client_key(request), 20):
        return _GENERIC_RESET
    if not throttle(db, "reset-mail:" + data.email, 3):
        return _GENERIC_RESET
    lock_mutations(db)
    user = db.query(User).filter(User.email == data.email).first()
    if user:
        token = secrets.token_urlsafe(32)
        now = datetime.utcnow()
        db.query(PasswordReset).filter(PasswordReset.expires_at < now).delete()
        db.add(PasswordReset(token_hash=hashlib.sha256(token.encode()).hexdigest(), user_id=user.id,
                             expires_at=now + timedelta(minutes=settings.reset_token_minutes)))
        db.commit()
        tasks.add_task(send_reset_email, user.email, token)
    return _GENERIC_RESET


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, request: Request, db: Session = Depends(get_db)):
    if not throttle(db, "reset-use:" + client_key(request), 20):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    lock_mutations(db)
    token = db.get(PasswordReset, hashlib.sha256(data.reset_token.encode()).hexdigest())
    now = datetime.utcnow()
    if token is None or token.used_at is not None or token.expires_at <= now:
        raise HTTPException(400, "Código inválido, expirado ou já utilizado.")
    user = db.get(User, token.user_id)
    user.password_hash = hash_password(data.new_password)
    db.query(PasswordReset).filter(PasswordReset.user_id == user.id, PasswordReset.used_at.is_(None)).update({"used_at": now})
    db.commit()
    return {"message": "Senha redefinida. Entre novamente com a nova senha."}
