"""Email delivery: local SMTP/Mailpit or Gmail HTTPS, without a paid provider."""
import base64
import json
import logging
import smtplib
import ssl
from email.message import EmailMessage
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from app.core.config import settings

logger = logging.getLogger(__name__)


def _post_json(url, body, headers=None):
    request = Request(url, data=body, headers=headers or {}, method="POST")
    with urlopen(request, timeout=15) as response:
        return json.load(response)


def send_reset_email(email: str, token: str) -> None:
    message = EmailMessage()
    message["From"] = settings.mail_from
    message["To"] = email
    message["Subject"] = "RUNOVER — recuperação de senha"
    message.set_content(
        f"Cole este código na tela Recuperar senha do RUNOVER:\n\n{token}\n\n"
        f"Ele expira em {settings.reset_token_minutes} minutos e só pode ser usado uma vez.\n"
        "Se você não solicitou a alteração, ignore este e-mail."
    )
    try:
        if settings.mail_backend == "smtp":
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
                if settings.smtp_starttls:
                    smtp.starttls(context=ssl.create_default_context())
                if settings.smtp_username:
                    smtp.login(settings.smtp_username, settings.smtp_password)
                smtp.send_message(message)
        elif settings.mail_backend == "gmail":
            credentials = _post_json(
                "https://oauth2.googleapis.com/token",
                urlencode({"client_id": settings.gmail_client_id,
                           "client_secret": settings.gmail_client_secret,
                           "refresh_token": settings.gmail_refresh_token,
                           "grant_type": "refresh_token"}).encode(),
                {"Content-Type": "application/x-www-form-urlencoded"},
            )
            _post_json(
                "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
                json.dumps({"raw": base64.urlsafe_b64encode(message.as_bytes()).decode()}).encode(),
                {"Content-Type": "application/json", "Authorization": "Bearer " + credentials["access_token"]},
            )
        else:
            logger.warning("Password recovery delivery is not configured (MAIL_BACKEND).")
            raise RuntimeError("Password recovery email delivery is not configured.")
    except Exception:
        # Do not log tokens, recipients, provider bodies or credentials.
        logger.error("Password recovery email delivery failed; check the mail configuration.")
        raise
