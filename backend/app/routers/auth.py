import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db, lock_mutations
from app.core.security import create_access_token, hash_password, verify_password
from app.models import (
    AuthAttempt,
    EmailVerificationToken,
    OAuthIdentity,
    PasswordReset,
    PasswordResetToken,
    User,
)
from app.schemas import (
    ForgotPasswordRequest,
    LoginRequest,
    OAuthLoginRequest,
    RegisterRequest,
    RegisterResponse,
    ResendVerificationRequest,
    ResendVerificationResponse,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.services.oauth import create_unique_username, verify_identity
from app.services.usernames import username_taken
from app.services.email import (
    EmailDeliveryError,
    send_email_verification_email,
    send_password_reset_email,
)

router = APIRouter(prefix="/auth", tags=["autenticação"])
logger = logging.getLogger(__name__)
_GENERIC_RESET = {"message": "Se esse e-mail estiver cadastrado, enviaremos um código de recuperação. Verifique também o spam."}
_VERIFICATION_GATE_CODE = "email_verification_required"


def _generic_verification_response() -> ResendVerificationResponse:
    """A resposta do reenvio, sempre a mesma, com a espera que o servidor aplica.

    O número vem da mesma configuração que o portão de reenvio confere, para o
    aplicativo contar exatamente os segundos que a API exige.
    """
    return ResendVerificationResponse(
        message=(
            "Se esse e-mail estiver cadastrado e ainda precisar confirmar, "
            "enviaremos um novo código. Verifique também o spam."
        ),
        resend_after_seconds=settings.email_verification_cooldown_seconds,
    )


def _verification_gate_error(message: str) -> HTTPException:
    """403 com seletor de saída, para o aplicativo não ter que adivinhar.

    Conta desativada e conta sem e-mail confirmado têm o mesmo status e caminhos
    opostos: uma se reativa com a senha, a outra só entra com o código do
    e-mail. Escolher pela frase seria quebrar a cada reescrita de texto.
    """
    return HTTPException(403, {"message": message, "code": _VERIFICATION_GATE_CODE})


def _token_digest(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _deliver_password_reset(email: str, username: str, code: str) -> None:
    try:
        send_password_reset_email(email, username, code)
    except EmailDeliveryError:
        logger.warning("Password reset email delivery failed; check mail settings.")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _new_code() -> str:
    return f"{secrets.randbelow(1_000_000_000_000):012d}"


def _issue_verification_code(db: Session, user: User) -> str:
    """Gera o código da conta e descarta os pendentes anteriores.

    Guarda só o hash, como no de recuperação: a tabela não pode virar uma
    lista de códigos válidos para quem tiver leitura dela.
    """
    now = _now()
    db.query(EmailVerificationToken).filter(
        EmailVerificationToken.user_id == user.id,
        EmailVerificationToken.used_at.is_(None),
    ).update({"used_at": now})
    code = _new_code()
    db.add(EmailVerificationToken(
        user_id=user.id,
        token_hash=_token_digest(code),
        expires_at=now + timedelta(minutes=settings.email_verification_expire_minutes),
    ))
    return code


def _send_verification_code(user: User, code: str) -> bool:
    """Entrega o código do cadastro antes de a conta existir de verdade.

    Devolve `False` quando o envio foi só para o log (modo de console). Sem
    provedor configurado e sem esse modo, o cadastro falha em vez de criar uma
    conta que não consegue entrar.
    """
    try:
        send_email_verification_email(user.email, user.username, code)
    except EmailDeliveryError:
        if not settings.mail_console_fallback:
            raise HTTPException(
                503,
                "Não foi possível enviar o código de confirmação. Tente novamente.",
            ) from None
        logger.info("Email verification code (console fallback): %s", code)
        return False
    return True


def _record_failed_verification_attempt(db: Session, user: User) -> None:
    """Cinco erros queimam o código pendente da conta.

    O mesmo teto do token de recuperação: adivinhar 12 dígitos já é inviável,
    mas uma conta não pode virar alvo infinito e barato de tentativa.
    """
    pending = db.query(EmailVerificationToken).filter(
        EmailVerificationToken.user_id == user.id,
        EmailVerificationToken.used_at.is_(None),
    ).order_by(EmailVerificationToken.created_at.desc()).with_for_update().first()
    if pending is None:
        return
    pending.attempts += 1
    if pending.attempts >= 5:
        pending.used_at = _now()
    db.commit()


def _user_by_email(db: Session, email: str) -> User | None:
    """Busca pelo endereço já normalizado pelo schema.

    O banco guarda minúsculas, mas as contas anteriores ao portão podem ter
    sido criadas com maiúscula no cadastro antigo — a comparação não pode
    depender de sorte.
    """
    return db.query(User).filter(func.lower(User.email) == email).first()


def _assert_can_enter(user: User) -> None:
    """As duas portas de entrada (login e reativação) passam por aqui.

    Chamado só depois de a senha ser conferida, e nessa ordem: sem a senha
    certa ninguém descobre se a conta existe, se está desativada ou se ainda
    espera a confirmação do e-mail.
    """
    if not user.is_active:
        raise HTTPException(403, "Esta conta está desativada. Reative-a para continuar.")
    if user.email_verified_at is None:
        raise _verification_gate_error(
            "Confirme seu e-mail para entrar. Digite o código que enviamos no "
            "cadastro, ou peça um novo.",
        )


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


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, request: Request, db: Session = Depends(get_db)):
    """Cria a conta pendente e manda o código. Não devolve token.

    A conta passa a existir para reservar o nome de usuário e para o código ter
    a quem pertencer, mas sem confirmar o endereço ela não entra no aplicativo:
    é o portão que impede a quinta conta criada em dois minutos.
    """
    if not throttle(db, "register:" + client_key(request), 20):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    if not throttle(db, "register-mail:" + data.email, 3, minutes=60 * 24):
        raise HTTPException(429, "Muitos códigos para esse e-mail. Aguarde um dia.")
    lock_mutations(db)
    if username_taken(db, data.username):
        raise HTTPException(400, "Esse nome de usuário já está em uso.")
    if _user_by_email(db, data.email):
        raise HTTPException(400, "Já existe uma conta com esse e-mail.")
    user = User(full_name=data.full_name, username=data.username, email=data.email,
                password_hash=hash_password(data.password), photo_url=data.photo_url or None)
    db.add(user)
    db.flush()
    code = _issue_verification_code(db, user)
    # Entrega antes do commit: se o provedor estiver fora do ar, o cadastro
    # falha inteiro em vez de deixar um usuário sem código nenhum.
    delivered = _send_verification_code(user, code)
    db.commit()
    return RegisterResponse(
        email=user.email,
        expires_in_minutes=settings.email_verification_expire_minutes,
        resend_after_seconds=settings.email_verification_cooldown_seconds,
        message=(
            "Conta criada. Digite o código que enviamos para o seu e-mail para entrar."
        ),
        debug_code=None if delivered else code,
    )


@router.post("/verify-email", response_model=TokenResponse)
def verify_email(data: VerifyEmailRequest, request: Request, db: Session = Depends(get_db)):
    """Troca o código do e-mail pela primeira sessão.

    Só existe um caminho para dentro do aplicativo a partir daqui: este
    endpoint é o único que emite token para conta recém-criada.
    """
    if not throttle(db, "verify:" + client_key(request), 20):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    lock_mutations(db)
    user = _user_by_email(db, data.email)
    if user is None:
        raise HTTPException(400, "Código inválido, expirado ou já utilizado.")
    if user.email_verified_at is not None:
        raise HTTPException(400, "Esta conta já está confirmada. Entre com a sua senha.")
    token = db.query(EmailVerificationToken).filter(
        EmailVerificationToken.user_id == user.id,
        EmailVerificationToken.token_hash == _token_digest(data.code),
        EmailVerificationToken.used_at.is_(None),
    ).with_for_update().first()
    if token is None:
        _record_failed_verification_attempt(db, user)
        raise HTTPException(400, "Código inválido, expirado ou já utilizado.")
    expires_at = token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= _now():
        token.used_at = _now()
        db.commit()
        raise HTTPException(400, "Código expirado. Peça um novo.")
    token.used_at = _now()
    user.email_verified_at = _now()
    db.commit()
    return TokenResponse(access_token=create_access_token(user.id, user.password_hash))


@router.post("/resend-verification", response_model=ResendVerificationResponse)
def resend_verification(data: ResendVerificationRequest, request: Request, db: Session = Depends(get_db)):
    """Reenvia o código de um cadastro ainda não confirmado.

    A resposta é sempre a mesma: saber se o endereço existe é trabalho do
    login, não deste endpoint.
    """
    if not throttle(db, "resend-ip:" + client_key(request), 20) or not throttle(
        db, "resend-mail:" + data.email, 5, minutes=60 * 24
    ):
        return _generic_verification_response()
    lock_mutations(db)
    user = _user_by_email(db, data.email)
    if user is None or user.email_verified_at is not None:
        return _generic_verification_response()
    now = _now()
    recent = db.query(EmailVerificationToken).filter(
        EmailVerificationToken.user_id == user.id,
        EmailVerificationToken.created_at >= now
        - timedelta(seconds=settings.email_verification_cooldown_seconds),
    ).first()
    if recent:
        return _generic_verification_response()
    code = _issue_verification_code(db, user)
    try:
        _send_verification_code(user, code)
    except HTTPException:
        # O cadastro pode gritar 503; o reenvio não. Aqui a diferença de resposta
        # diria "esta conta existe e ainda espera código", e o rollback mantém o
        # código que a pessoa já tem em mãos válido até o próximo envio.
        db.rollback()
        logger.warning("Verification code resend delivery failed; check mail settings.")
        return _generic_verification_response()
    db.commit()
    return _generic_verification_response()


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, request: Request, db: Session = Depends(get_db)):
    request_client = client_key(request)
    if not throttle(db, "login-ip:" + request_client, 60) or not throttle(
        db, "login:" + data.email + ":" + request_client, 15
    ):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    user = _user_by_email(db, data.email)
    if len(data.password.encode()) > 72 or not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(401, "E-mail ou senha incorretos.")
    _assert_can_enter(user)
    return TokenResponse(access_token=create_access_token(user.id, user.password_hash))


@router.post("/reactivate", response_model=TokenResponse)
def reactivate(data: LoginRequest, request: Request, db: Session = Depends(get_db)):
    """Reativa uma conta desativada temporariamente (volta tudo como estava)."""
    request_client = client_key(request)
    if not throttle(db, "reactivate-ip:" + request_client, 60) or not throttle(
        db, "reactivate:" + data.email + ":" + request_client, 15
    ):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    user = _user_by_email(db, data.email)
    if len(data.password.encode()) > 72 or not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(401, "E-mail ou senha incorretos.")
    if user.email_verified_at is None:
        raise _verification_gate_error(
            "Confirme seu e-mail antes de reativar. Peça um novo código na tela "
            "de confirmação.",
        )
    if user.is_active:
        raise HTTPException(400, "Esta conta já está ativa. Entre normalmente.")
    user.is_active = True
    user.deactivated_at = None
    db.commit()
    return TokenResponse(access_token=create_access_token(user.id, user.password_hash))


@router.post("/oauth/{provider}", response_model=TokenResponse)
def oauth_login(
    provider: str,
    data: OAuthLoginRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    if not throttle(db, "oauth:" + provider + ":" + client_key(request), 40):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    try:
        identity = verify_identity(provider, data.id_token)
    except RuntimeError as exc:
        raise HTTPException(503, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(401, str(exc)) from exc

    lock_mutations(db)
    linked = db.query(OAuthIdentity).filter_by(
        provider=provider, subject=identity["subject"]
    ).first()
    if linked:
        _assert_can_enter(linked.user)
        return TokenResponse(
            access_token=create_access_token(linked.user_id, linked.user.password_hash)
        )

    if not identity.get("email"):
        db.rollback()
        raise HTTPException(
            401,
            "O provedor não retornou um e-mail verificado para criar a conta pela primeira vez.",
        )

    # Never auto-link by e-mail: linking an existing account needs proof of both credentials.
    if _user_by_email(db, identity["email"]):
        db.rollback()
        raise HTTPException(
            409,
            "Este e-mail já tem uma conta RUNOVER. Entre com ela para evitar vincular contas sem autorização.",
        )

    full_name = (identity.get("full_name") or identity["email"].split("@", 1)[0]).strip()
    if len(full_name) < 2:
        full_name = "Corredor RUNOVER"
    user = User(
        full_name=full_name[:120],
        username=create_unique_username(db, identity["email"]),
        email=identity["email"],
        password_hash=hash_password(secrets.token_urlsafe(40)),
        photo_url=identity.get("photo_url"),
        # O provedor já respondeu email_verified: pedir um código aqui seria
        # friction sem ganhar nada, e o login social é o caminho barato de
        # identidade real.
        email_verified_at=_now(),
    )
    db.add(user)
    db.flush()
    db.add(OAuthIdentity(user_id=user.id, provider=provider, subject=identity["subject"]))
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        linked = db.query(OAuthIdentity).filter_by(
            provider=provider, subject=identity["subject"]
        ).first()
        if linked:
            _assert_can_enter(linked.user)
            return TokenResponse(
                access_token=create_access_token(linked.user_id, linked.user.password_hash)
            )
        raise HTTPException(409, "Não foi possível criar a conta social.") from exc
    return TokenResponse(access_token=create_access_token(user.id, user.password_hash))


@router.post("/oauth/{provider}/reactivate", response_model=TokenResponse)
def oauth_reactivate(provider: str, data: OAuthLoginRequest, request: Request, db: Session = Depends(get_db)):
    """Reativa conta desativada a partir da identidade social verificada.

    Nunca cria conta nem vincula e-mail: só reativa um vínculo existente.
    O token provado aqui é a mesma prova do login social.
    """
    request_client = client_key(request)
    if not throttle(db, "oauth-reactivate-ip:" + request_client, 60) or not throttle(
        db, "oauth-reactivate:" + provider + ":" + request_client, 15
    ):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    try:
        identity = verify_identity(provider, data.id_token)
    except RuntimeError as exc:
        raise HTTPException(503, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(401, str(exc)) from exc

    lock_mutations(db)
    linked = db.query(OAuthIdentity).filter_by(
        provider=provider, subject=identity["subject"]
    ).first()
    if not linked:
        raise HTTPException(
            404,
            "Nenhuma conta vinculada a este login social. Entre com e-mail e senha.",
        )
    if linked.user.is_active:
        raise HTTPException(400, "Esta conta já está ativa. Entre normalmente.")
    linked.user.is_active = True
    linked.user.deactivated_at = None
    db.commit()
    return TokenResponse(
        access_token=create_access_token(linked.user_id, linked.user.password_hash)
    )


@router.post("/forgot-password")
def forgot_password(
    data: ForgotPasswordRequest,
    request: Request,
    tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    if not throttle(db, "reset-ip:" + client_key(request), 20):
        return _GENERIC_RESET
    if not throttle(db, "reset-mail:" + data.email, 3):
        return _GENERIC_RESET
    lock_mutations(db)
    user = _user_by_email(db, data.email)
    if not user:
        return _GENERIC_RESET

    now = datetime.now(timezone.utc)
    cooldown_start = now - timedelta(seconds=settings.password_reset_cooldown_seconds)
    recent = db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.created_at >= cooldown_start,
    ).first()
    if recent:
        return _GENERIC_RESET

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
    tasks.add_task(_deliver_password_reset, user.email, user.username, code)
    return _GENERIC_RESET


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest, request: Request, db: Session = Depends(get_db)):
    if not throttle(db, "reset-use:" + client_key(request), 20):
        raise HTTPException(429, "Muitas tentativas. Aguarde 15 minutos.")
    lock_mutations(db)
    if data.reset_token is not None:
        token = db.get(PasswordReset, _token_digest(data.reset_token))
        now = datetime.utcnow()
        if token is None or token.used_at is not None or token.expires_at <= now:
            raise HTTPException(400, "Código inválido, expirado ou já utilizado.")
        user = db.get(User, token.user_id)
        if user is None:
            raise HTTPException(400, "Código inválido, expirado ou já utilizado.")
        user.password_hash = hash_password(data.new_password)
        # Receber o código no e-mail é a mesma prova que a confirmação do
        # cadastro pede: quem conclui uma recuperação controla a caixa.
        user.email_verified_at = user.email_verified_at or datetime.utcnow()
        db.query(PasswordReset).filter(
            PasswordReset.user_id == user.id,
            PasswordReset.used_at.is_(None),
        ).update({"used_at": now})
        db.commit()
        return {"message": "Senha redefinida. Entre novamente com a nova senha."}

    reset = db.query(PasswordResetToken).join(User).filter(
        func.lower(User.email) == data.email,
        PasswordResetToken.token_hash == _token_digest(data.reset_code),
        PasswordResetToken.used_at.is_(None),
    ).with_for_update().first()
    if not reset:
        active_reset = db.query(PasswordResetToken).join(User).filter(
            func.lower(User.email) == data.email,
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
    user.email_verified_at = user.email_verified_at or datetime.now(timezone.utc)
    reset.used_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Senha redefinida. Entre novamente com a nova senha."}
