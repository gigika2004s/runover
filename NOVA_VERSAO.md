# Corridas, segurança e progresso

## O que mudou

- Recuperação de senha com código aleatório de uso único, hash no banco, validade de 15 minutos e limite de solicitações. A resposta pública nunca contém o código nem confirma a existência da conta.
- Trocar/redefinir senha invalida os JWT anteriores. Após esta atualização todos precisam entrar novamente, porque os tokens antigos não têm a assinatura vinculada à senha.
- Corridas privadas persistidas independentemente de conquista. Histórico paginado, mapa, distância, duração dos trechos ativos, ritmo e resultado da conquista.
- Respostas que rejeitam explicitamente a corrida (400/403/422) liberam o percurso local para correção ou continuação. Falhas de rede, conflitos e erros do servidor preservam a solicitação para reenvio sem alteração.
- Gravação local por conta; pausa/continuação; restauração ao voltar à tela; reenvio manual da mesma solicitação, com identificação imutável. Uma confirmação perdida não duplica a corrida nem os pontos.
- Metas semanais UTC: 10 km, 3 dias de corrida, 3 conquistas. Medalhas: primeira corrida, primeira conquista, 5 km em uma corrida, 10 corridas. Recorde de maior distância. Sem pontos extras por medalha.
- Meta coletiva de 30 km por semana e contribuição individual, visíveis aos integrantes. A corrida contribui para a equipe da qual a pessoa participa no momento do envio, independentemente de pontuar individualmente ou pela equipe.
- Timeouts HTTP e mensagens de erro; uma falha temporária na inicialização não apaga a sessão.

## Dados e atualização

O backend cria quatro tabelas adicionais: `mutation_lock`, `password_resets`, `auth_attempts` e `runs`. Não remove ou altera tabelas existentes. Faça backup antes do deploy. A criação ocorre na inicialização e pode ser executada explicitamente de `backend/`:

```bash
python -c 'from app import models; from app.core.database import initialize_database; initialize_database()'
```

Não existe conversão de conquistas antigas para corridas: o projeto não guardava os percursos completos. Pontos e histórico anteriores permanecem; as metas e estatísticas de corridas começam com os novos registros.

Uma linha de bloqueio no banco serializa gravações do jogo, inclusive criação de territórios, para evitar decisões concorrentes inconsistentes. É uma solução para o volume do MVP; deve ser substituída por uma estratégia mais granular conforme a carga crescer.

O endpoint antigo `POST /territories/claim` retorna 410 e pede atualização. Publicar backend e aplicativo juntos. Novos clientes usam `POST /runs`; reapresentar o mesmo ID e conteúdo retorna o resultado original. Reutilizar o ID com conteúdo diferente ou reapresentar o mesmo percurso como outra corrida retorna 409.

## Execução e testes

Python 3.12.10, Flutter 3.47.2 / Dart 3.13.2. Na raiz:

```bash
python -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/requirements-dev.txt
PYTHONPATH=backend backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

Em `backend/`:

```bash
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Em `app/`:

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web --dart-define=API_BASE=http://127.0.0.1:8000
```

Use a URL HTTPS do backend no build distribuído. O CI repete os testes do backend, o analisador, os testes e o build web. Os testes usam contas fictícias, banco temporário e captura de e-mails; não chamam produção.

## Envio de recuperação sem domínio próprio

Copie as variáveis de `backend/.env.example` para a configuração do host ou exporte-as no terminal. O backend não carrega o arquivo `.env` automaticamente. Nunca versione valores secretos.

### Testes locais: SMTP/Mailpit

Execute Mailpit (https://github.com/axllent/mailpit), configure `MAIL_BACKEND=smtp`, `MAIL_FROM=runover@example.test`, `SMTP_HOST=127.0.0.1`, `SMTP_PORT=1025` e `SMTP_STARTTLS=false`. Abra a caixa local do Mailpit, solicite recuperação e cole o código recebido no aplicativo. O e-mail não é entregue a caixas externas nesse modo. Para SMTP remoto, use TLS e credenciais; não desative TLS em uma conexão externa.

### Envio real: Gmail via HTTPS

1. Crie uma conta Gmail dedicada e um projeto Google Cloud.
2. Habilite Gmail API e configure um cliente OAuth e a tela de consentimento.
3. Autorize somente a conta remetente com `https://www.googleapis.com/auth/gmail.send`, solicitando acesso offline.
4. Configure `MAIL_BACKEND=gmail`, `MAIL_FROM` com o endereço da conta, `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET` e `GMAIL_REFRESH_TOKEN` nas variáveis do servidor.
5. Confirme entrega real e persistência da autorização antes de publicar. Apps OAuth em modo de teste podem ter credenciais temporárias; siga as exigências do Google para o uso escolhido.

O Gmail é um serviço proprietário com cotas; o código da integração não depende de SDK proprietário. A API HTTPS evita a restrição de SMTP no Render gratuito. Não há uma conta de produção configurada por este código. Com `MAIL_BACKEND=disabled`, a recuperação mantém a resposta genérica e registra apenas que o envio precisa de configuração, sem registrar código ou destinatário.

## Regras e limites

- Corridas: até 10.000 pontos, duração entre 1 segundo e 6 horas, pelo menos 10 metros, envio em até 7 dias. Horários devem ter fuso e ser crescentes; coordenadas finitas dentro dos limites geográficos; velocidade máxima de 8,3 m/s.
- Pausas criam trechos separados: distância/tempo não incluem os intervalos entre trechos. Uma corrida pausada pode ser salva, mas não conquista território, pois o intervalo não comprova um percurso contínuo.
- Conquistas: laço fechado, um único polígono não vazio, área entre 100 m² e 25 km². Um erro de conquista preserva a corrida válida e informa o motivo, sem crédito parcial de pontos.
- Percursos são privados e acessíveis apenas ao dono. A opção de conquistar publica a área formada no mapa; o aplicativo explica isso antes do envio. Não existe feed público de corridas nesta versão.
- O armazenamento local usa SharedPreferences, separado pelo ID da conta. Limpar dados do app/navegador remove corridas ainda não enviadas. A opção de remover uma cópia local não exclui uma corrida já recebida pelo servidor.
- Ao sair do aplicativo, a gravação é pausada. Rastreamento em segundo plano/tela bloqueada, feed social, segmentos e exportação GPX permanecem para uma etapa posterior.
- As validações e a identificação única reduzem reenvio e dados impossíveis; não comprovam que o GPS veio de um aparelho íntegro. Coordenadas fabricadas com horários plausíveis continuam sendo uma limitação.
