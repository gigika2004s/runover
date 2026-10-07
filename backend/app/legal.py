"""Página pública de privacidade (URL exigida na tela de consentimento OAuth)."""

from fastapi.responses import HTMLResponse

PRIVACY_HTML = """<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RUNOVER! — Política de Privacidade</title>
<style>body{font-family:system-ui,sans-serif;max-width:720px;margin:2rem auto;padding:0 1rem;line-height:1.6;color:#1a1a1a}h1{font-size:1.6rem}h2{font-size:1.15rem;margin-top:1.6rem}</style>
</head>
<body>
<h1>RUNOVER! — Política de Privacidade</h1>
<p>Última atualização: 2026. O RUNOVER! transforma corridas em conquista de territórios por geolocalização.</p>
<h2>Dados que coletamos</h2>
<p>Cadastro (nome, apelido, e-mail, foto opcional), localização GPS durante o uso, trajetos registrados e dados de jogo (territórios, pontos, nível, tempo de jogo). No login com Google, recebemos nome, e-mail e foto.</p>
<h2>Para que usamos</h2>
<p>Executar o serviço (mapa, conquistas, ranking, perfil), segurança e prevenção a fraudes. Não vendemos dados nem os usamos para publicidade de terceiros.</p>
<h2>Cookies</h2>
<p>Usamos armazenamento local para sessão, preferências e rascunhos. Cookies não essenciais são gerenciados no próprio app.</p>
<h2>Compartilhamento</h2>
<p>Apenas operadores técnicos necessários (hospedagem, banco de dados, envio de e-mails, mapas), sob nossas instruções, além de exigências legais.</p>
<h2>Seus direitos (LGPD)</h2>
<p>Acesso, correção, anonimização, eliminação, portabilidade e revogação de consentimento. A conta pode ser excluída no app em Editar perfil › Segurança › Excluir conta. Contato pelo suporte do RUNOVER! informando o e-mail de cadastro.</p>
<h2>Retenção e segurança</h2>
<p>Dados guardados enquanto a conta existir; senhas só como hash irreversível; tráfego criptografado.</p>
</body>
</html>
"""


def privacy_response() -> HTMLResponse:
    return HTMLResponse(content=PRIVACY_HTML)
