from html import escape

import httpx

from app.core.config import settings


class EmailDeliveryError(RuntimeError):
    pass


def send_password_reset_email(email: str, username: str, code: str) -> None:
    """Send a reset code via SMTP2GO's transactional email API."""
    if not settings.smtp2go_api_key or not settings.mail_from_email:
        raise EmailDeliveryError("Email delivery is not configured.")

    escaped_name = escape(username)
    escaped_code = escape(code)
    payload = {
        "sender": {"email": settings.mail_from_email, "name": settings.mail_from_name},
        "to": [{"email": email, "name": username}],
        "subject": "Código para redefinir sua senha do RUNOVER!",
        "text_body": (
            f"Olá, {username}. Seu código para redefinir a senha é {code}. "
            f"Ele expira em {settings.password_reset_expire_minutes} minutos. "
            "Se você não solicitou a redefinição, ignore esta mensagem."
        ),
        "html_body": (
            f"<p>Olá, {escaped_name}.</p><p>Seu código para redefinir a senha é:</p>"
            f"<p style='font-size:24px;font-weight:bold'>{escaped_code}</p>"
            f"<p>Ele expira em {settings.password_reset_expire_minutes} minutos. "
            "Se você não solicitou a redefinição, ignore esta mensagem.</p>"
        ),
    }
    try:
        response = httpx.post(
            "https://api.smtp2go.com/v3/email/send",
            headers={"X-Smtp2go-Api-Key": settings.smtp2go_api_key},
            json=payload,
            timeout=settings.api_timeout_seconds,
        )
        response.raise_for_status()
        data = response.json()
        if data.get("data", {}).get("succeeded", 0) < 1:
            raise EmailDeliveryError("SMTP2GO did not accept the email.")
    except (httpx.HTTPError, ValueError) as exc:
        raise EmailDeliveryError("Could not deliver password reset email.") from exc
