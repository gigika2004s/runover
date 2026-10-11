from html import escape

import httpx

from app.core.config import settings


class EmailDeliveryError(RuntimeError):
    pass


def send_password_reset_email(email: str, username: str, code: str) -> None:
    """Send a reset code via Resend's transactional email API."""
    if not settings.resend_api_key or not settings.mail_from_email:
        raise EmailDeliveryError("Email delivery is not configured.")

    escaped_name = escape(username)
    escaped_code = escape(code)
    sender = f"{settings.mail_from_name} <{settings.mail_from_email}>"
    payload = {
        "from": sender,
        "to": [email],
        "subject": "Código para redefinir sua senha do RUNOVER!",
        "text": (
            f"Olá, {username}. Seu código para redefinir a senha é {code}. "
            f"Ele expira em {settings.password_reset_expire_minutes} minutos. "
            "Se você não solicitou a redefinição, ignore esta mensagem."
        ),
        "html": (
            f"<p>Olá, {escaped_name}.</p><p>Seu código para redefinir a senha é:</p>"
            f"<p style='font-size:24px;font-weight:bold'>{escaped_code}</p>"
            f"<p>Ele expira em {settings.password_reset_expire_minutes} minutos. "
            "Se você não solicitou a redefinição, ignore esta mensagem.</p>"
        ),
    }
    try:
        response = httpx.post(
            "https://api.resend.com/emails",
            headers={"Authorization": f"Bearer {settings.resend_api_key}"},
            json=payload,
            timeout=settings.api_timeout_seconds,
        )
        response.raise_for_status()
        data = response.json()
        if not data.get("id"):
            raise EmailDeliveryError("Resend did not accept the email.")
    except (httpx.HTTPError, ValueError) as exc:
        raise EmailDeliveryError("Could not deliver password reset email.") from exc
