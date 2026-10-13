import re
import secrets

import httpx
from google.auth.exceptions import TransportError
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token as google_id_token

from app.core.config import settings
from app.services.usernames import username_taken

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


def verify_identity(provider: str, token: str) -> dict:
    if provider == "google":
        return _verified_google_identity(token)
    raise ValueError("Provedor de login não suportado.")


def create_unique_username(db, email: str) -> str:
    base = email.split("@", 1)[0].lower()
    base = re.sub(r"[^a-z0-9_]", "", base) or "runner"
    base = base[:18]
    if len(base) < 3:
        base = (base + "run")[:3]
    candidate = base
    while username_taken(db, candidate):
        candidate = f"{base[:16]}_{secrets.token_hex(3)}"
    return candidate

