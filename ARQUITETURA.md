# Arquitetura do RUNOVER!

O RUNOVER é um aplicativo de corrida com conquista de territórios por
geolocalização. O percurso pode ser registrado individualmente ou associado
à equipe do usuário.

## Contexto do projeto

O projeto está relacionado ao trabalho **Desenvolvimento de um sistema
gamificado de domínio urbano via geolocalização — RUNOVER!**, da FATEC Zona Sul.
Autores: Giovana de Andrade Farias, Marcos Vinicius Rocha Santana e
Vítor Viana Soares Messias.

A especificação de referência reúne requisitos funcionais (RF), requisitos
não funcionais (RNF) e regras de negócio (RN). Esses identificadores aparecem
nos comentários do código para facilitar a rastreabilidade.

## Tecnologias

| Camada | Tecnologia | Responsabilidade |
|---|---|---|
| Aplicativo | Flutter e Dart | Interface, mapas e gravação do percurso |
| Estado do aplicativo | Provider | Autenticação e perfil |
| Persistência local | SharedPreferences | Sessão e corridas ainda não enviadas, separadas por conta |
| API | FastAPI e Pydantic | Endpoints, contratos e validação das entradas |
| Acesso a dados | SQLAlchemy | Persistência e transações |
| Banco local | SQLite | Desenvolvimento e testes |
| Banco de servidor | PostgreSQL | Persistência no ambiente configurado pelo Render |
| Geometria | Shapely | Polígonos, áreas e interseções |
| Mapas | flutter_map e OpenStreetMap | Exibição de percursos e territórios |
| Autenticação | bcrypt e JWT | Hash de senha e validação da sessão |

A implementação usa Flutter e Python. A alternativa inicial com Ionic e
Angular foi substituída durante a definição da arquitetura. As geometrias
são armazenadas em GeoJSON e processadas em Python; PostGIS não é exigido.

## Organização do código

### Backend

- `backend/app/main.py`: aplicação, rotas e territórios de exemplo.
- `backend/app/core/`: configuração, banco de dados e autenticação.
- `backend/app/models.py`: entidades persistidas.
- `backend/app/schemas.py`: contratos das requisições e respostas.
- `backend/app/geometry.py`: validação geométrica e cálculo de áreas.
- `backend/app/routers/`: autenticação, usuários, equipes, corridas,
  territórios, ranking, notificações e localização.
- `backend/app/services/`: pontuação, notificações e envio de e-mail.
- `backend/tests/`: testes de integração com banco descartável.

### Aplicativo

- `app/lib/main.dart`: entrada da aplicação.
- `app/lib/state/app_state.dart`: estado de autenticação e perfil.
- `app/lib/services/api_client.dart`: comunicação HTTP e tratamento de erros.
- `app/lib/services/run_store.dart`: armazenamento local dos percursos.
- `app/lib/services/run_sync.dart`: envio e recuperação de corridas pendentes.
- `app/lib/screens/`: mapa, gravação, histórico, resumo, ranking, equipes e perfil.
- `app/lib/widgets/`: componentes de nível e identificação dos territórios.
- `app/test/`: testes de interface, persistência e comunicação.

## Corridas e conquistas

A corrida é registrada independentemente da conquista. Cada envio tem uma
identificação única e um conteúdo verificável, permitindo repetir uma
solicitação sem duplicar o registro ou a pontuação.

Ao solicitar uma conquista, o percurso deve formar um laço fechado. A API
verifica coordenadas, horários, velocidade, geometria e limites de área.
Um laço que cobre pelo menos 35% de um território existente pode transferir
sua posse; caso contrário, pode criar um território novo.

A tolerância de fechamento, os critérios de sobreposição e os parâmetros de
pontuação ficam em `backend/app/core/config.py`. A pontuação combina uma
base por relevância e um bônus proporcional à área. Nas conquistas em nome
de uma equipe, os pontos são atribuídos à equipe.

As regras atuais de pausa, reenvio e validação estão descritas em
[NOVA_VERSAO.md](NOVA_VERSAO.md).

## Histórico e integridade

As posses dos territórios e os eventos de pontuação são mantidos como
histórico. O ranking é calculado a partir dos eventos, e a posse atual vem
da conquista mais recente.

O registro da corrida e seus efeitos sobre territórios, pontuação e
notificações são transacionais. Um bloqueio no banco serializa as gravações
do jogo. Essa abordagem atende ao MVP, mas deverá ser reavaliada antes de
ampliar a concorrência.

A inicialização atual adiciona tabelas sem apagar o histórico existente.
As instruções de atualização estão em [NOVA_VERSAO.md](NOVA_VERSAO.md).

## Perfis e visibilidade

O percurso completo de uma corrida é acessível apenas ao próprio usuário.
Ao conquistar, a área formada é publicada no mapa do jogo.

O perfil pode ser público ou privado. A rota de perfil privado bloqueia
consultas de terceiros; o ranking mantém informações competitivas públicas.
As notificações de conquista, perda, nível e posição são consultadas dentro
do aplicativo.

## Execução e publicação

- [RODAR.md](RODAR.md): preparação, execução local e testes no Android.
- [NOVA_VERSAO.md](NOVA_VERSAO.md): atualização, regras e configuração.
- `render.yaml`: configuração do backend e PostgreSQL no Render.
- `.github/workflows/ci.yml`: testes do backend, análise do Flutter,
  testes do aplicativo e build web.

O endereço da API é definido no build por `--dart-define=API_BASE=...`.
No Android, o endereço deve ser acessível pelo aparelho. `127.0.0.1` aponta
para o próprio dispositivo, não para o computador de desenvolvimento.

## Limitações atuais

- A gravação é pausada ao sair do aplicativo; GPS em segundo plano precisa
  de implementação e validação específicas no dispositivo.
- As notificações são internas; envio push não está implementado.
- As verificações do percurso não comprovam a integridade do dispositivo GPS.
- Testes de carga e otimizações de busca espacial permanecem pendentes.
- O build Android ainda usa assinatura de desenvolvimento.
- O envio real de recuperação de senha depende de configuração externa.
