"""Tokens compactos HS256 usando apenas a biblioteca padrão.

Motivo: as libs JWT de terceiros acumulam classes inteiras de
vulnerabilidade (confusão HMAC/assimétrico via PEM/DER/JWK, `crit`
desconhecido, JWKS/redirect/SSRF, ReDoS) sem patch disponível. Nosso uso
é só HS256 simétrico com segredo do servidor e algoritmo fixo, então um
codec mínimo elimina essas superfícies por construção:

- nenhum parse de PEM/DER/JWK/JWKS existe aqui;
- nenhum outro algoritmo além de HS256 é aceito;
- a assinatura é sempre HMAC com o segredo, comparada em tempo constante.
"""

import base64
import binascii
import hashlib
import hmac
import json
import time
from datetime import datetime, timezone

_MAX_TOKEN_BYTES = 8192


class InvalidToken(Exception):
    """Token malformado, com assinatura inválida ou expirado."""


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(segment: str) -> bytes:
    if len(segment) > _MAX_TOKEN_BYTES:
        raise InvalidToken("segmento longo demais")
    padding = "=" * (-len(segment) % 4)
    try:
        return base64.urlsafe_b64decode((segment + padding).encode("ascii"))
    except (ValueError, binascii.Error, UnicodeEncodeError):
        raise InvalidToken("base64url inválido")


def _to_jsonable(value: object) -> object:
    if isinstance(value, datetime):
        moment = value if value.tzinfo else value.replace(tzinfo=timezone.utc)
        return int(moment.timestamp())
    if isinstance(value, dict):
        return {key: _to_jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_to_jsonable(item) for item in value]
    return value


def encode(payload: dict, secret: str) -> str:
    header = _b64url_encode(b'{"alg":"HS256","typ":"JWT"}')
    body = _b64url_encode(
        json.dumps(
            _to_jsonable(payload),
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("utf-8")
    )
    signing_input = f"{header}.{body}".encode("ascii")
    signature = hmac.new(secret.encode("utf-8"), signing_input, hashlib.sha256)
    return f"{header}.{body}.{_b64url_encode(signature.digest())}"


def decode(token: str, secret: str) -> dict:
    """Valida e devolve o payload. Qualquer problema vira InvalidToken."""
    if len(token) > _MAX_TOKEN_BYTES:
        raise InvalidToken("token longo demais")
    parts = token.split(".")
    if len(parts) != 3:
        raise InvalidToken("formato inválido")
    try:
        header = json.loads(_b64url_decode(parts[0]))
    except (ValueError, RecursionError, UnicodeDecodeError):
        raise InvalidToken("cabeçalho inválido")
    if not isinstance(header, dict) or header.get("alg") != "HS256":
        raise InvalidToken("algoritmo inesperado")
    try:
        signing_input = f"{parts[0]}.{parts[1]}".encode("ascii")
        expected = hmac.new(
            secret.encode("utf-8"), signing_input, hashlib.sha256
        ).digest()
        actual = _b64url_decode(parts[2])
    except (ValueError, UnicodeEncodeError):
        raise InvalidToken("assinatura inválida")
    if not hmac.compare_digest(expected, actual):
        raise InvalidToken("assinatura inválida")
    try:
        payload = json.loads(_b64url_decode(parts[1]))
    except (ValueError, RecursionError, UnicodeDecodeError):
        raise InvalidToken("payload inválido")
    if not isinstance(payload, dict):
        raise InvalidToken("payload inválido")
    exp = payload.get("exp")
    if isinstance(exp, bool) or not isinstance(exp, (int, float)):
        raise InvalidToken("expiração ausente")
    if exp <= time.time():
        raise InvalidToken("token expirado")
    return payload
