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
<p>Última atualização: 8 de outubro de 2026. O RUNOVER! transforma corridas em conquista de territórios por geolocalização.</p>
<h2>Uso seguro e fair play</h2>
<p>Use o app respeitando o trânsito, o ambiente e seus limites físicos. GPS falso, emuladores, deslocamentos impossíveis e exploração de falhas são proibidos. O RUNOVER! não substitui orientação médica nem avaliação das condições de segurança do trajeto.</p>
<h2>Moedas, missões e cosméticos</h2>
<p>Corridas e conquistas podem gerar moedas virtuais, experiência, sequências e recompensas de missão. Moedas e cosméticos não têm valor monetário, não são dinheiro eletrônico e não podem ser vendidos, trocados ou convertidos fora do RUNOVER!. Catálogo, preços e recompensas podem mudar para preservar o equilíbrio do jogo.</p>
<h2>Dados que coletamos</h2>
<p>Cadastro (nome, apelido, e-mail, foto opcional, pronomes opcionais e preferências), localização GPS durante o uso, trajetos registrados e dados de jogo (territórios, pontos, nível, tempo de jogo, moedas, cosméticos, favoritos e missões). No login com Google, recebemos nome, e-mail e foto quando disponíveis.</p>
<h2>Para que usamos e suas escolhas</h2>
<p>Executar o serviço (mapa, conquistas, ranking, perfil, missões e loja), segurança e prevenção a fraudes. Você controla a visibilidade do perfil e o compartilhamento de atividades nas configurações. Não vendemos dados nem os usamos para publicidade de terceiros.</p>
<h2>Cookies</h2>
<p>Usamos armazenamento local para sessão, preferências e rascunhos. Cookies não essenciais são gerenciados no próprio app.</p>
<h2>Compartilhamento</h2>
<p>Apenas operadores técnicos necessários (hospedagem, banco de dados, envio de e-mails, mapas), sob nossas instruções, além de exigências legais.</p>
<h2>Seus direitos (LGPD)</h2>
<p>Acesso, correção, anonimização, eliminação, portabilidade e revogação de consentimento. A conta pode ser excluída no app em Editar perfil › Segurança › Excluir conta. Contato pelo suporte do RUNOVER! informando o e-mail de cadastro.</p>
<h2>Retenção, exclusão e segurança</h2>
<p>Dados guardados enquanto a conta existir, salvo retenção necessária por obrigação legal. A conta pode ser excluída no app em Editar perfil › Segurança › Excluir conta. Senhas são armazenadas apenas como hash irreversível e o tráfego usa criptografia.</p>
<h2>Alterações</h2>
<p>Podemos atualizar esta política para refletir mudanças no serviço ou na legislação. Mudanças relevantes serão comunicadas no app quando necessário.</p>
</body>
</html>
"""


def privacy_response() -> HTMLResponse:
    return HTMLResponse(content=PRIVACY_HTML)
