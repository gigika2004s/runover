import re
import secrets

import httpx
from google.auth.exceptions import TransportError
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token as google_id_token
from jose import JWTError, jwt

from app.core.config import settings
from app.models import User

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"


def _client_ids(raw: str) -> list[str]:
    return [value.strip() for value in raw.split(",") if value.strip()]


def _verified_google_identity(token: str) -> dict:
    audiences = _client_ids(settings.google_oauth_client_ids)
    if not audiences:
        raise RuntimeError("O login com Google ainda não está configurado no servidor.")

    claims = None
    for audience in audiences:
        try:
            claims = google_id_token.verify_oauth2_token(
                token, GoogleRequest(), audience=audience
            )
            break
        except ValueError:
            continue
        except TransportError as exc:
            raise RuntimeError("O Google está temporariamente indisponível.") from exc
    if claims is None or not claims.get("sub"):
        raise ValueError("Token do Google inválido ou expirado.")
    if not claims.get("email") or claims.get("email_verified") is not True:
        raise ValueError("O Google não confirmou o endereço de e-mail desta conta.")
    return {
        "subject": claims["sub"],
        "email": claims["email"].strip().lower(),
        "full_name": claims.get("name") or claims["email"].split("@", 1)[0],
        "photo_url": claims.get("picture"),
    }


def _verified_apple_identity(token: str) -> dict:
    audiences = _client_ids(settings.apple_oauth_client_ids)
    if not audiences:
        raise RuntimeError("O login com Apple ainda não está configurado no servidor.")

    try:
        header = jwt.get_unverified_header(token)
        if header.get("alg") != "RS256" or not header.get("kid"):
            raise ValueError("Token da Apple inválido.")
        try:
            response = httpx.get(APPLE_JWKS_URL, timeout=8.0)
            response.raise_for_status()
        except httpx.HTTPError as exc:
            raise RuntimeError("A Apple está temporariamente indisponível.") from exc
        key = next(
            (item for item in response.json().get("keys", []) if item.get("kid") == header["kid"]),
            None,
        )
        if key is None:
            raise ValueError("Chave de assinatura da Apple não encontrada.")

        claims = None
        for audience in audiences:
            try:
                claims = jwt.decode(
                    token,
                    key,
                    algorithms=["RS256"],
                    audience=audience,
                    issuer="https://appleid.apple.com",
                )
                break
            except JWTError:
                continue
    except (ValueError, JWTError) as exc:
        raise ValueError("Não foi possível validar a identidade Apple.") from exc

    if claims is None or not claims.get("sub"):
        raise ValueError("Token da Apple inválido ou expirado.")
    email = claims.get("email")
    verified = claims.get("email_verified")
    if email and verified not in (True, "true"):
        raise ValueError("A Apple não confirmou o endereço de e-mail desta conta.")
    return {
        "subject": claims["sub"],
        # Apple may omit e-mail after the first authorization. Existing
        # identities still sign in by stable subject; only first-time accounts
        # require the verified address to create the RUNOVER profile.
        "email": email.strip().lower() if email else None,
        "full_name": email.split("@", 1)[0] if email else None,
        "photo_url": None,
    }


def verify_identity(provider: str, token: str) -> dict:
    if provider == "google":
        return _verified_google_identity(token)
    if provider == "apple":
        return _verified_apple_identity(token)
    raise ValueError("Provedor de login não suportado.")


def create_unique_username(db, email: str) -> str:
    base = email.split("@", 1)[0].lower()
    base = re.sub(r"[^a-z0-9_]", "", base) or "runner"
    base = base[:18]
    if len(base) < 3:
        base = (base + "run")[:3]
    candidate = base
    while db.query(User).filter_by(username=candidate).first():
        candidate = f"{base[:16]}_{secrets.token_hex(3)}"
    return candidate

