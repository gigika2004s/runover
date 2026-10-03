# RUNOVER!

Aplicativo Flutter para registrar corridas, acompanhar progresso e disputar territórios por geolocalização. O Flutter Web e a API FastAPI são servidos pelo mesmo serviço Render em `https://runover.onrender.com`.

## Tecnologias

- Flutter 3.47.2 e Dart 3.13.2 para Android e Web.
- FastAPI, Pydantic e SQLAlchemy no backend.
- PostgreSQL do Neon em produção; SQLite em desenvolvimento e testes.
- Shapely para geometria; `flutter_map` e OpenStreetMap para mapas.
- SharedPreferences para sessão e rascunhos de corrida separados por conta.

O backend está em `backend/app/`; as telas, serviços e testes Flutter estão em `app/lib/` e `app/test/`. `backend/app/geometry.py` calcula e valida as áreas; `backend/app/routers/` contém as rotas da API.

## Executar localmente

Requisitos: Python 3.12.10, Flutter 3.47.2, Dart 3.13.2 e, para Android, JDK 17 e Android SDK.

No PowerShell, a partir da raiz:

```powershell
py -3.12 -m venv backend\.venv
backend\.venv\Scripts\python.exe -m pip install -r backend\requirements-dev.txt
Set-Location backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Em outro terminal:

```powershell
Set-Location app
flutter pub get --enforce-lockfile
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:8000
```

A API local fica em `http://127.0.0.1:8000`; `/health` verifica sua disponibilidade. Para Android Emulator, use `http://10.0.2.2:8000` como `API_BASE`. Em um aparelho físico, use um endereço IP acessível pela rede local.

## Testes e build

Na raiz do repositório:

```powershell
$env:PYTHONPATH = "backend"
backend\.venv\Scripts\python.exe -m unittest discover -s backend/tests -v
backend\.venv\Scripts\python.exe -m pytest backend/tests/test_password_reset.py backend/tests/test_claim_integrity.py -q
```

Na pasta `app/`:

```powershell
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE=https://runover.onrender.com
```

O CI executa as suítes backend com SQLite e PostgreSQL, análise e testes Flutter, e build Web. Os testes usam dados descartáveis; não configure o Neon de produção como banco de teste.

## Regras e dados

Uma corrida aceita até 10.000 pontos, dura de 1 segundo a 6 horas, precisa registrar pelo menos 10 metros e deve ser enviada em até 7 dias. Coordenadas devem ser válidas, horários crescentes com fuso informado e velocidade plausível. O limite de velocidade é 8,3 m/s.

Para conquistar, o percurso precisa fechar um laço dentro de 30 metros do início e formar uma área entre 100 m² e 25 km². Uma corrida pausada pode ser salva, mas trechos separados não conquistam território. A posse e a pontuação mantêm histórico; o percurso completo continua privado, enquanto a área conquistada aparece no mapa.

O envio usa identificadores estáveis para que uma repetição da mesma corrida não duplique pontuação. Reutilizar um identificador com conteúdo diferente resulta em conflito. Rascunhos enfileirados ficam no aparelho, separados por conta; limpar os dados do app ou navegador remove rascunhos ainda não enviados.

A recuperação envia um código de 12 dígitos, armazena somente seu hash, expira em 30 minutos e invalida o código após cinco tentativas incorretas. Solicitações têm intervalo mínimo de 60 segundos. A resposta é genérica para não revelar se a conta existe. Redefinir a senha invalida sessões anteriores.

A inicialização do backend cria tabelas de forma aditiva e não apaga dados existentes. Faça backup do Neon antes de atualizar. Corridas antigas não podem ser reconstruídas a partir de conquistas que não armazenaram o percurso.

## Render e Neon

A branch de produção é `main`. O Blueprint em `render.yaml` descreve um serviço Docker chamado `runover`, com build no `Dockerfile` da raiz e health check em `/health`. O container compila o Flutter Web e o FastAPI serve a aplicação na raiz e mantém os endpoints da API no mesmo domínio.

`DATABASE_URL` é uma variável secreta (`sync: false`) do serviço Render e deve conter a conexão do Neon. O Blueprint não cria nem substitui o banco. Preserve esse valor ao sincronizar a configuração. `SECRET_KEY` deve ser um segredo forte no ambiente de produção.

A recuperação de senha por código usa a API SMTP2GO. Configure `SMTP2GO_API_KEY` e `MAIL_FROM_EMAIL` no Render; `MAIL_FROM_NAME` pode permanecer como `RUNOVER!`. Nunca coloque credenciais neste arquivo ou no Git.

O remetente precisa estar verificado no SMTP2GO. `DATABASE_URL` e `SECRET_KEY` devem ser definidos no painel como variáveis secretas; o Blueprint não cria um banco Render substituto.

Após um deploy saudável, `https://runover.onrender.com/` abre o app e `https://runover.onrender.com/health` retorna o status da API.

## Corridas e territórios

As corridas são privadas; ao optar por conquistar, a área formada é publicada no mapa. Corridas pendentes permanecem no aparelho e são reenviadas com o mesmo identificador para evitar duplicação. `POST /runs` é o fluxo atual; o endpoint antigo `POST /territories/claim` retorna 410.

A API valida coordenadas, fusos horários, sequência dos pontos, velocidade, distância, duração e idade da corrida. Para conquistar, o percurso precisa formar um laço fechado válido com área entre 100 m² e 25 km². Percursos pausados podem ser salvos, mas trechos separados não formam uma conquista contínua.

Histórico de posse e pontuação é preservado. A inicialização do backend cria tabelas de forma aditiva; ainda assim, faça backup do Neon antes de atualizar. Não há migração automática de corridas antigas que nunca tiveram o percurso armazenado.

## Android

Para gerar um APK local, use uma URL acessível pelo dispositivo:

```powershell
flutter build apk --release --dart-define=API_BASE=http://192.168.1.72:8000
```

Substitua o endereço pelo IP do backend na rede local ou use a URL HTTPS publicada. O build de desenvolvimento usa assinatura de debug; configure uma chave própria antes de distribuir o aplicativo.

Com depuração USB habilitada, instale o APK com `adb install -r build/app/outputs/flutter-apk/app-release.apk`. Mantenha o app aberto durante a gravação; rastreamento contínuo em segundo plano não é garantido nesta versão.

## Atualização deste guia

Este README é a documentação única do repositório. Atualize as seções correspondentes sempre que mudar setup, contratos da API, regras de corrida, banco, testes ou deploy; não crie outros arquivos Markdown para esses tópicos.
