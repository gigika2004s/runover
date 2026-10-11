"""Política de endereço de e-mail no cadastro.

O portão de confirmação só serve se o endereço significar uma caixa de correio
que a pessoa controla. Domínio descartável não significa, e o mesmo endereço
com outro tamanho de caixa (maiúsculas) não é outra pessoa. As duas coisas são
corrigidas aqui, na entrada, antes de o usuário existir no banco.
"""

DISPOSABLE_EMAIL_DOMAINS = frozenset(
    {
        "10minutemail.com",
        "20minutemail.com",
        "dispostable.com",
        "emailondeck.com",
        "emailtemporario.com.br",
        "fakeinbox.com",
        "getairmail.com",
        "getnada.com",
        "guerrillamail.com",
        "guerrillamail.info",
        "maildrop.cc",
        "mailinator.com",
        "mintemail.com",
        "mohmal.com",
        "sharklasers.com",
        "spam4.me",
        "spamgourmet.com",
        "temp-mail.org",
        "tempail.com",
        "tempr.email",
        "tempmail.com",
        "throwawaymail.com",
        "trashmail.com",
        "yopmail.com",
    }
)


def normalize_email(value: str) -> str:
    """Minúsculas e sem espaços: `Ana@Exemplo.com` e `ana@example.com` são a
    mesma caixa de correio e não podem virar duas contas."""
    return value.strip().lower()


def email_domain(value: str) -> str:
    return normalize_email(value).rsplit("@", 1)[-1]


def is_disposable(value: str) -> bool:
    return email_domain(value) in DISPOSABLE_EMAIL_DOMAINS
