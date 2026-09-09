# RUNOVER! — Registro da sessão

Recap completo de tudo que foi feito nesta sessão, do TCC em PDF até o app
rodando com a mecânica final. Onde uma decisão foi tomada e depois revista,
deixei os dois momentos registrados — mas o que vale pra rodar o projeto hoje
é sempre o **estado final** (seção 8 e as tabelas de arquivos).

## 1. Leitura do TCC

Li o PDF `DESENVOLVIMENTO DE UM SISTEMA GAMIFICADO DE DOMÍNIO URBANO VIA
GEOLOCALIZAÇÃO - RUNOVER!.pdf` (autores: Giovana de Andrade Farias, Marcos
Vinicius Rocha Santana, Vítor Viana Soares Messias — FATEC Zona Sul), extraindo:

- 19 requisitos funcionais (RF01–RF19)
- 20 requisitos não funcionais (RNF01–RNF20)
- 18 regras de negócio (RN01–RN18)
- O protótipo visual (telas de cadastro, login, mapa, conquista, ranking, histórico)

## 2. Recomendação de stack

O RNF15 original fixava **Ionic + Angular**. Recomendei trocar por:

- **Flutter (Dart)** no mobile — compila nativo pra Android/iOS (uma WebView
  como Ionic é menos confiável pra rastreamento de GPS em segundo plano, que
  é o requisito mais sensível do app: RF14, RNF08).
- **Python** no back-end — boa integração com bibliotecas geoespaciais
  (Shapely) pra validar a geometria dos territórios.

Você aprovou essa troca.

## 3. Artifact publicado: arquitetura técnica

Publiquei um Artifact ("Arquitetura RUNOVER!") documentando a decisão, com
diff do RNF15, tabela da stack, diagrama de componentes, diagrama de
sequência da conquista e a modelagem de dados (posse de território como
histórico, não campo fixo).

## 4. Construção do app (MVP inicial)

Você pediu pra eu "fazer o app". Antes de começar, perguntei duas coisas:

- **Ambiente**: Flutter não estava instalado → você pediu pra instalar agora.
  Instalei a SDK 3.47.1 via `git clone` do canal stable em `C:\flutter` (fora
  da pasta do usuário de propósito — Flutter tem problemas de toolchain com
  espaço no caminho, e `Giovana Farias` tem espaço). Nem Android SDK nem
  Chrome estavam disponíveis; o Edge foi o alvo de execução usado.
- **Escopo do MVP**: você escolheu o **núcleo do jogo** (RF01–RF12: cadastro,
  login, mapa, conquista de território, pontuação, ranking).

Nessa primeira versão a conquista era "corra um laço fechado cobrindo pelo
menos 40% de um território pré-desenhado". Funcionou, testei via `curl`
ponta a ponta — mas essa lógica foi revisada duas vezes depois (seções 5 e
8) até chegar no formato final.

## 5. Sincronização com o .docx atualizado

Você trouxe `DESENVOLVIMENTO DE UM SISTEMA GAMIFICADO DE DOMÍNIO URBANO VIA
GEOLOCALIZAÇÃO - RUNOVER! (1).docx` como "o arquivo mais atualizado do
projeto". Ele tinha os mesmos RF/RNF/RN do PDF, mas acrescentava 5 seções
novas com diagramas formais (UML): 2.4 Casos de Uso, 2.5 Atividades, 2.6
Classes, 2.7 Entidade-Relacionamento, 2.8 Objetos. Apliquei as mudanças que
esses diagramas traziam:

1. **Equipes viraram entidade de verdade** — o diagrama de classes mostra
   `Equipe` com `membros`, `criador`, e território com `equipeProprietaria`.
   Implementei criação/entrada/saída de equipe e conquista em nome da
   equipe, com a pontuação indo pra equipe e não pro indivíduo (RN15).
2. **Notificação e Geolocalização como entidades persistidas** — notificações
   de conquista/perda passaram a ficar salvas e marcáveis como lidas, e cada
   posição do usuário é registrada (auditoria, RNF20).
3. **Vocabulário alinhado** — troquei os status de território de
   `livre`/`dominado` (inventado por mim) para `disponivel`/`conquistado`,
   os nomes literais do enum `status` no diagrama de classes.
4. **(Revisado depois — seção 8)** Nesse momento eu também troquei a mecânica
   de conquista pra "estar dentro de um raio de proximidade" do território,
   seguindo os diagramas UC06/UC11 ao pé da letra. Essa versão rodou e foi
   testada (conquista individual, conquista em nome de equipe, ranking misto
   de usuário/equipe), mas você pediu depois pra voltar ao modelo de laço
   fechado — ver seção 8.

### 5.1 Atualização do Word

O RNF15 do `.docx` ainda citava **Ionic e Angular**, defasado em relação à
troca de stack já aprovada (seção 2). Corrigi o parágrafo pra citar Flutter
(Dart) + Python, usando `python-docx` pra editar só aquele texto sem tocar
no resto do documento.

Isso exigiu uma pausa: o Word estava aberto (`WINWORD.exe`) segurando o
arquivo, e o primeiro save deu `PermissionError`. Fiz backup do arquivo
original (`_backup_antes_de_editar_RUNOVER.docx`), esperei você fechar o
Word, e então salvei. Conferi depois que os 41 arquivos de mídia (diagramas
+ protótipo) e os 444 parágrafos continuavam intactos — só o texto do RNF15
mudou.

## 6. Ajustes visuais pro protótipo do RF06

Você pediu duas correções visuais no mapa pra bater com o mockup do RF06:

1. **"A área dominada precisa ser linhas, não uma área redonda"** — troquei
   os círculos preenchidos por contorno de polígono (`PolygonLayer` com
   `color: Colors.transparent`), tanto no mapa geral quanto na tela de
   corrida.
2. **"Precisa ser igual ao protótipo do RF06"** — extraí a imagem do RF06 do
   próprio `.docx` pra comparar lado a lado e ajustei três coisas:
   - Territórios com **contorno orgânico/irregular** (polígono de 8 vértices
     com raio e ângulo variando por uma seed determinística), em vez dos
     quadrados perfeitos que eu tinha gerado.
   - **Coroa 👑 recolorida sólida por dono** (vermelho/rosa/verde conforme
     quem domina) via `ColorFiltered` + emoji, em vez do ícone de troféu
     genérico do Material Design.
   - **Mapa mais clean** — tiles do CartoDB Positron (claro, minimalista) em
     vez do OpenStreetMap padrão colorido.

## 7. Bugs encontrados e corrigidos ao longo da sessão

1. **`email-validator` faltando** — o `EmailStr` do Pydantic depende dele;
   adicionei em `requirements.txt`.
2. **Conflito `app/models/` (pasta vazia) vs. `app/models.py`** — removi a
   pasta.
3. **Crash real em produção**: ao testar o app no Edge, você mesma testou o
   fluxo (cadastro, mapa, ranking, histórico) e bateu num erro:
   `map_screen.dart` tentava centralizar o mapa (`MapController.move`) antes
   do widget `FlutterMap` existir na tela. Corrigido adiando a centralização
   pro frame seguinte (`WidgetsBinding.instance.addPostFrameCallback`).
4. **`flutter run -d edge` instável** — a conexão de debug (DWDS) com o Edge
   falhava de forma intermitente depois da primeira sessão. Troquei pra
   `flutter build web` + servidor estático (`python -m http.server`), mais
   robusto pra esse fim.

## 8. Mecânica final: laço fechado estilo Strava

Você pediu pra mudar de novo: em vez de escolher um território fixo e chegar
perto dele (raio, seção 5), a mecânica virou **estilo Strava** — a pessoa sai
correndo livremente, e se ela **fechar o próprio trajeto** (voltar pro ponto
de partida), aquela área forma ou retoma um território. Essa é a mecânica
que está rodando agora, e ela também é a leitura mais literal do RN05 ("um
território somente poderá ser conquistado se o usuário completar uma forma
geográfica").

Como funciona:

1. No mapa, o usuário aperta **"Iniciar corrida"** (sem escolher um
   território antes) e sai correndo livremente — a tela desenha o percurso
   ao vivo, com km/tempo/pace, igual um app de corrida de verdade.
2. Ao voltar a até 30m do ponto de partida (RN05), o app libera **"Finalizar
   e dominar"**.
3. O back-end valida a velocidade entre pontos consecutivos (RNF17/RN18,
   anti-GPS-falso), fecha o polígono do trajeto e compara com todos os
   territórios existentes:
   - Se o laço cobre **35% ou mais** de algum território já existente, esse
     território é **retomado** (troca de dono, com histórico de perda pro
     antigo dono).
   - Senão, nasce um **território novo** ali, com o formato exato do laço
     percorrido — o usuário pode dar um nome a ele.
4. Pontuação = base por relevância do local **+ bônus proporcional à área**
   do laço (RN09) — laços maiores valem mais.
5. Igual antes, dá pra conquistar em nome de uma equipe (RN15: pontos vão
   pra equipe, não pro indivíduo).

Retestei os três cenários via chamadas diretas à API: laço fechado cobrindo
um território existente (retomou, 745 pontos), laço em área vazia (criou
"Quintal do Runner2", 211 pontos) e laço não fechado (rejeitado com a
distância que falta pra fechar). Depois disso zerei o banco (`runover.db`)
pra você começar do zero, sem os usuários de teste.

## 9. Estado final dos arquivos

### Back-end (`runover/backend/`)

FastAPI + SQLite (substituindo PostgreSQL/PostGIS do desenho original —
Docker não estava disponível na máquina; a lógica geométrica usa **Shapely**
em Python, migrável pra PostGIS depois sem trocar as regras).

| Arquivo | O que faz |
|---|---|
| `app/main.py` | App FastAPI, CORS, cria tabelas, popula territórios de exemplo com contorno orgânico (Embu das Artes + Parque Ibirapuera) |
| `app/core/config.py` | Limiares das regras de negócio: tolerância de laço fechado, % mínima de sobreposição, velocidade máxima plausível, pontuação por relevância/área |
| `app/core/database.py` | Engine/sessão SQLAlchemy |
| `app/core/security.py` | Hash de senha (bcrypt), JWT, dependência `get_current_user` |
| `app/models.py` | Tabelas: `User`, `Team`, `TeamMember`, `Territory`, `TerritoryOwnership`, `ScoreEvent`, `Notification`, `LocationPing` |
| `app/schemas.py` | Contratos Pydantic de request/response (`ClaimRequest`/`ClaimResponse` pro laço fechado) |
| `app/geometry.py` | Fecha o polígono do trajeto (RN05), calcula área, sobreposição com territórios existentes e checagem anti-fraude (RNF17/RN18) |
| `app/services/scoring.py` | Dono atual = posse mais recente por território; pontuação de usuário **ou** equipe; ranking ao vivo (RN11) |
| `app/services/notifications.py` | Gera notificações de conquista/perda (RF18/RN16) |
| `app/routers/auth.py` | Registro, login, esqueci minha senha (RF01–RF04) |
| `app/routers/users.py` | Perfil, edição, perfil público, histórico (RF05, RF13, RF17, RF19) |
| `app/routers/teams.py` | Criar/entrar/sair de equipe (RF16/RN14/RN15) |
| `app/routers/territories.py` | Listar territórios, detalhe, e **`POST /territories/claim`** — fecha o laço e conquista ou cria um território |
| `app/routers/ranking.py` | Ranking misto de usuários e equipes (RF12) |
| `app/routers/notifications.py` | Listar notificações e marcar como lida (RF18) |
| `app/routers/location.py` | Registra cada posição do usuário para auditoria (RF14/RNF20) |

### App Flutter (`runover/app/`)

| Arquivo | O que faz |
|---|---|
| `lib/main.dart` | Entrada do app, tema, Provider |
| `lib/theme.dart` | Paleta RUNOVER! (laranja de rota + azul de território) |
| `lib/models.dart` | Classes Dart espelhando os schemas da API |
| `lib/widgets/crown_icon.dart` | Coroa colorida por dono (emoji + `ColorFiltered`), igual ao protótipo |
| `lib/services/api_client.dart` | Cliente HTTP; `claimTerritory()` envia o trajeto inteiro pro back-end |
| `lib/state/app_state.dart` | Estado de autenticação e perfil (`ChangeNotifier`) |
| `lib/screens/auth_gate.dart` | Decide entre tela de login e o app |
| `lib/screens/login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart` | RF01–RF04 |
| `lib/screens/home_shell.dart` | Navegação por abas (Mapa / Ranking / Equipe / Perfil) |
| `lib/screens/map_screen.dart` | Mapa clean (CartoDB Positron), territórios com contorno orgânico e coroa colorida, botão flutuante **"Iniciar corrida"** (RF06/RF07) |
| `lib/screens/tracking_screen.dart` | Gravação livre do percurso (km/tempo/pace ao vivo, estilo Strava); libera "Finalizar e dominar" ao fechar o laço; opção de conquistar para a equipe (RF08/RF09/RF14) |
| `lib/screens/teams_screen.dart` | Criar equipe, listar/entrar em equipes existentes, ver membros e sair (RF16) |
| `lib/screens/notifications_screen.dart` | Lista de notificações com marcação de lida (RF18) |
| `lib/screens/ranking_screen.dart` | RF12, com abas Jogadores/Equipes; cada linha mostra o nível e abre o perfil público ao toque (RF17) |
| `lib/screens/profile_screen.dart` | Perfil, nível + barra de progresso, estatísticas (pontos / territórios / tempo de jogo), edição (foto + privacidade), histórico, link dos termos (RF05, RF11, RF13, RF19) |
| `lib/screens/public_profile_screen.dart` | Perfil público de outro jogador — nível, pontos, territórios, posição; trata perfil privado (RF17 / RF05 / RN13) |
| `lib/screens/terms_screen.dart` | Texto dos Termos de Uso + Política de Privacidade (LGPD), aberto no cadastro e no perfil (RF02 / RNF02) |
| `lib/widgets/level_badge.dart` | Selo "Nv N" e barra de progresso até o próximo nível (RF11 / RN10) |

### Rodando agora

- Back-end: `http://127.0.0.1:8000`
- App (build web de produção, servido estaticamente): `http://127.0.0.1:5000`
- `flutter analyze` sem erros (só infos cosméticas de estilo) e `flutter build web` sem erros
- Banco (`runover.db`) zerado — sem usuários de teste

## 10. Fora do escopo desta sessão

Ficou pra depois: rastreamento de GPS em segundo plano real (hoje só grava
enquanto a tela de corrida está aberta), testes de carga com 1.000 usuários
simultâneos (RNF04/RNF05), migração de SQLite+Shapely para
PostgreSQL+PostGIS, build para Android/iOS de verdade, e notificações
**push** via FCM (hoje elas só existem dentro do app, não chegam com o app
fechado).

## 11. Sessão de continuação — "terminar o app"

### 11.1 Ambiente reinstalado do zero

Entre uma sessão e outra a máquina mudou: a pasta de usuário virou
`C:\Users\gio` (era `C:\Users\Giovana Farias`), o projeto foi movido para
`C:\Users\gio\Downloads\runover`, o Flutter (`C:\flutter`) sumiu e não havia
mais Python — a `venv` do backend apontava para um Python 3.12 que não existe
mais. Refiz tudo:

- **Python 3.12.10** via `winget install Python.Python.3.12` (fica em
  `C:\Users\gio\AppData\Local\Programs\Python\Python312`).
- **Git 2.55** via `winget install Git.Git` (`C:\Program Files\Git`) — o
  Flutter precisa dele no PATH.
- **Flutter 3.47.2 stable** (Dart 3.13.2) baixado como zip de
  `storage.googleapis.com` e extraído em **`C:\Users\gio\flutter`** (sem
  espaço no caminho). `flutter config --enable-web`.
- `venv` do backend recriada (`python -m venv venv` + `pip install -r
  requirements.txt`); a `venv` antiga quebrada foi apagada.
- `runover.db` apagado (o schema do `User` ganhou colunas novas — ver 11.2);
  ele se recria e repopula os territórios de exemplo no startup.

Para rodar, o PATH da sessão precisa ter `C:\Users\gio\flutter\bin` e
`C:\Program Files\Git\cmd`.

### 11.2 Requisitos que faltavam (fechados nesta sessão)

Comparando o `.docx` com o que já existia, estas lacunas foram implementadas:

1. **Progressão / níveis (RF11, RN10)** — o nível sai da pontuação acumulada,
   com custo triangular por nível (`level_step_points = 150`: N2=150, N3=450,
   N4=900, N5=1500…). `app/services/scoring.py::level_info()` devolve
   `(nível, progresso 0..1, pontos que faltam)`. Exposto em
   `UserPublic`/`UserProfile`/`TeamDetail`/`RankingEntry`. No app: selo "Nv N"
   no ranking/perfis e barra de progresso no perfil, no perfil público e na
   equipe. Ao subir de nível numa conquista, o backend gera notificação tipo
   `nivel` e o `ClaimResponse` traz `new_level`/`leveled_up` (a tela de
   corrida mostra "Você subiu para o nível N!").
2. **Perfil de terceiros (RF17)** — `lib/screens/public_profile_screen.dart`,
   aberto tocando numa linha de jogador no ranking. Usa o
   `GET /users/{username}` (que já existia) e agora respeita privacidade.
3. **Termos de uso (RF02) + privacidade (RF05)** —
   `lib/screens/terms_screen.dart` com o texto de Termos + Política de
   Privacidade (base LGPD, RNF02), linkado no cadastro e no perfil. Novo campo
   `User.is_public` (default `true`); `PATCH /users/me` aceita `is_public`; o
   perfil público responde **403 "Este perfil é privado."** para terceiros
   quando desligado (RN13). Foto de perfil: campo de URL no cadastro e na
   edição de perfil (`photo_url`), renderizada como avatar.
4. **Tempo de jogo (RF19) + notificação de ranking (RF18)** — nova coluna
   `User.play_seconds`, somada a cada conquista pela duração do trajeto
   (`track[-1].timestamp - track[0].timestamp`, teto de 6h). Card "Tempo de
   jogo" no perfil. A cada conquista o backend compara a posição de **todos**
   os usuários antes/depois (`scoring.user_rank_positions()`) e gera
   notificação tipo `ranking` para quem mudou de lugar — tanto quem sobe
   ("Você subiu para a Nª posição no ranking!") quanto quem foi ultrapassado
   ("Você caiu para a Nª posição no ranking.").

### 11.3 Testes

- Backend: teste ponta a ponta via HTTP cobrindo RF01–RF19 e RN01–RN15 —
  **57/57 checagens passam** (cadastro/login/recuperação com as regras RN01–RN03,
  rota protegida, seed de territórios, RN05 laço não fechado, RNF17/RN18 GPS
  falso, conquista individual e em área vazia, RN07, níveis + level-up,
  `play_seconds`, ranking com nível, histórico, perfil público + 403 de perfil
  privado, equipe com RN14/RN15, e notificação de mudança de ranking para quem
  sobe **e** para quem é ultrapassado). Script em
  `AppData\Local\Temp\claude\...\scratchpad\e2e.py`.
- App: `flutter analyze` (só 9 infos cosméticas de estilo, zero erros/warnings),
  `flutter test` (2/2) e `flutter build web` sem erros.

### 11.4 Build Android (APK) para testar no celular

Instalada a toolchain Android que faltava:

- **JDK 17** (`winget Microsoft.OpenJDK.17`) → `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot`
- **Android SDK** em `C:\Users\gio\Android\Sdk` (cmdline-tools, platform-tools,
  platforms android-35/36, build-tools 35/36, NDK r28c, CMake 3.22.1).
  `flutter config --android-sdk` e `--jdk-dir` já apontam pra lá.

**Pegadinha:** o `commandlinetools` "latest" atual (v23) tem um `sdkmanager`
que é só um wrapper de aviso de depreciação e **quebra** (`0xC0000409`) quando
o Gradle o invoca pra baixar o NDK. Troquei pelo `commandlinetools-win-11076708`
(sdkmanager 12.0, funcional) em `Sdk\cmdline-tools\latest`. As licenças foram
aceitas escrevendo os hashes conhecidos em `Sdk\licenses\`.

**Rede:** `ApiClient.baseUrl` agora vem de
`--dart-define=API_BASE=...` (padrão `http://127.0.0.1:8000`). O
`AndroidManifest.xml` ganhou `ACCESS_FINE/COARSE_LOCATION`, `INTERNET`,
`android:usesCleartextTraffic="true"` e `android:label="RUNOVER!"`.

**Gerar o APK** (com o back-end em `--host 0.0.0.0` e a porta 8000 liberada no
Firewall — passo a passo em `RODAR.md` seção 2b):

```
flutter build apk --release --dart-define=API_BASE=http://<IP-DO-PC>:8000
# ou, menor, split por arquitetura:
flutter build apk --release --split-per-abi --dart-define=API_BASE=http://<IP-DO-PC>:8000
```

Saída em `build\app\outputs\flutter-apk\`. O `--release` assina com a chave de
debug (`signingConfig = signingConfigs.getByName("debug")` no
`app/build.gradle.kts`), então instala direto por "fontes desconhecidas".
Nesta sessão gerei o APK com `API_BASE=http://192.168.1.72:8000`.
