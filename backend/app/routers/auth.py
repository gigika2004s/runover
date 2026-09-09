from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import create_access_token, hash_password, verify_password
from app.models import User
from app.schemas import (
    ForgotPasswordRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)

router = APIRouter(prefix="/auth", tags=["autenticação"])

# Tokens de redefinição em memória — suficiente para o protótipo (RF04).
# Em produção isso vira e-mail + tabela com expiração.
_reset_tokens: dict[str, str] = {}


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
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        # não revela se o e-mail existe
        return {"message": "Se esse e-mail estiver cadastrado, enviaremos instruções."}

    token = create_access_token(f"reset:{user.id}")
    _reset_tokens[token] = user.id
    return {
        "message": (
            "Em produção este token seria enviado por e-mail. "
            "No protótipo, use-o diretamente em /auth/reset-password."
        ),
        "reset_token": token,
    }


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    user_id = _reset_tokens.pop(data.reset_token, None)
    if not user_id:
        raise HTTPException(400, "Token de redefinição inválido ou já utilizado.")

    user = db.get(User, user_id)
    if not user:
        raise HTTPException(400, "Usuário não encontrado.")

    user.password_hash = hash_password(data.new_password)
    db.commit()
    return {"message": "Senha redefinida com sucesso."}
