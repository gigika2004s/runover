---
name: runover-git-workflow
description: Fluxo de Git e GitHub do projeto RUNOVER (misaiaBR/runover) - remotes origin e upstream, sincronizacao obrigatoria antes de trabalhar, nomes de branch, estilo de mensagem de commit, fluxo de pull request e merge, resolucao de conflitos e o que nunca pode entrar no Git. Use sempre que houver qualquer operacao git no runover - fetch, pull, branch, commit, push, conflito (conflict), pull request, merge, release ou deploy - e quando o usuario mencionar git, branch, commit, PR, merge, push, pull, rebase, conflito, conflict ou deploy no projeto runover.
---

# RUNOVER: fluxo de Git e GitHub

Convencoes de Git e GitHub do repositorio RUNOVER.

**Escopo desta skill:** apenas o que e especifico do *fluxo git* - remotes, sincronizacao, branches, commits e pull requests.

**Fora do escopo:** setup local, comandos de teste, regras de corrida, banco de dados, Render/Neon e deploy. Tudo isso ja esta no `README.md` do repositorio - leia a secao correspondente em vez de duplicar aqui. O `README.md` e a documentacao unica do projeto; nunca crie novos arquivos Markdown para esses topicos (a unica excecao existente e `AUTH_PROVIDERS.md`, sobre OAuth).

## Remotes

| Remote | URL | Papel |
| --- | --- | --- |
| `origin` | `https://github.com/misaiaBR/runover.git` | Repositorio canonico. O push vai para ca. |
| `upstream` | `https://github.com/gigika2004s/runover.git` | Espelho de terceiro. Somente leitura. |

`main` e a unica branch de longa duracao e e **producao**: o Render publica a cada push nela. Nunca commite direto na `main`.

## Ambiente

Este projeto roda em Windows com **PowerShell** (nao cmd): separe comandos com `;`, pois `&&` e invalido no PowerShell 5.1. As credenciais ficam no Git Credential Manager (`credential.helper = manager`), entao fetch e push funcionam sem pedir senha - mas exporte `GIT_TERMINAL_PROMPT=0` antes, para o git falhar rapido em vez de abrir um prompt que trava a execucao.

## Passo 0 - sincronizar antes de tocar em qualquer coisa

Clones locais deste projeto costumam estar muito atrasados (ja foram encontrados 77 commits atras da `main`). Antes de ler codigo, criar branch ou editar:

```powershell
$env:GIT_TERMINAL_PROMPT="0"
git fetch origin --prune
git pull --ff-only origin main
git status --short --branch
```

- `--ff-only` e obrigatorio. Se falhar, a branch divergiu: **pare e pergunte** antes de qualquer outra acao.
- A arvore precisa estar limpa. Artefatos ignorados (`app/build/`, `backend/runover.db`, `.venv/`) sao esperados; qualquer outro arquivo nao rastreado precisa de decisao explicita.
- Nunca use `git reset --hard`, `git clean -fd`, `git checkout -- .` nem force-push sem confirmacao explicita do usuario.

## Passo 1 - branch a partir da main

```powershell
git checkout -b fix/nome-curto-do-problema
```

Padrao observado no `origin`: `tipo/topico-em-kebab-case`.

| Prefixo | Uso | Exemplos reais no repo |
| --- | --- | --- |
| `fix/` | correcao de bug | `fix/profile-device-photo-picker`, `fix/refresh-weekly-goals-on-run` |
| `feature/` | funcionalidade nova | `feature/system-aware-dark-theme` |
| `docs/` | documentacao | `docs/referenciar-documentacao-inicial` |
| `ui/` | ajuste visual | `ui/compact-app-footer`, `ui/footer-in-profile` |

O repo usa `feature/`, nao `feat/`. `codex/*` e `coderabbit/*` sao branches de automacao: nunca crie, reutilize nem faca push nelas.

## Passo 2 - commit

Estilo **atual**, predominante nos commits recentes: ingles, modo imperativo, primeira letra maiuscula, sem prefixo de tipo, sem ponto final, assunto de ate cerca de 60 caracteres.

```
Label weekly goals as local time
Refresh run progress after upload
Add compact footer to login screen
Remove duplicate footer from profile content
```

Estilo **anterior**, ainda valido para mudancas com escopo claro - Conventional Commits com escopo (`profile`, `ci`, `app`):

```
feat(profile): choose photo from device gallery
fix(profile): preserve photo URL validation feedback
chore(ci): remove temporary lock export step
```

Existem commits em portugues no historico (`Corrige e reorganiza a edicao de perfil`), mas destoam da convencao corrente - escreva o assunto em ingles.

Regras:

- Um commit por mudanca logica. Nao misture Flutter e backend no mesmo commit, salvo se a mudanca for genuinamente transversal.
- Nunca commite arquivo gerado ou ignorado (`app/build/`, `.dart_tool/`, `runover.db`, `.env`, `__pycache__`).
- Confira o que entrou antes de commitar: `git status --short` e `git diff --cached --stat`.
- Corpo do commit, quando necessario, explica **por que** a mudanca foi feita, nao repete o que o diff ja mostra.

## Passo 3 - push e pull request

```powershell
git push -u origin fix/nome-curto-do-problema
```

Depois abra o PR contra `main`. O historico mostra `Merge pull request #14 from misaiaBR/fix/refresh-weekly-goals-on-run`: o merge entra por **merge commit**, feito no GitHub - nao por squash nem rebase, e nao localmente. Nao faca merge do seu proprio PR nem apague a branch remota sem pedido explicito.

Antes de abrir o PR, rode localmente os mesmos checks da CI. Os comandos estao na secao "Testes e build" do `README.md`; o workflow e `.github/workflows/ci.yml`.

## Passo 4 - sincronizar a branch e resolver conflitos

`pull.rebase` esta como `false` neste repositorio, entao sincronize com merge:

```powershell
git fetch origin
git merge origin/main
```

Em conflito: entenda os dois lados, resolva o arquivo, `git add` e `git commit`. Nunca descarte a versao do outro lado sem entender a mudanca. Conflito em `backend/app/models.py`, `backend/app/schemas.py` ou `app/pubspec.lock` merece confirmacao antes do commit - esses arquivos quebram a aplicacao inteira quando ficam inconsistentes.

Force-push somente na sua propria branch de trabalho e somente com `--force-with-lease`. Nunca em `main` nem em branch compartilhada.

## Nunca

- Nunca commite direto na `main`. Todo trabalho entra por branch + pull request.
- Nunca faca force-push na `main` ou em branch que nao seja sua.
- Nunca commite segredo - `DATABASE_URL`, `SECRET_KEY`, `SMTP2GO_API_KEY`, `MAIL_FROM_EMAIL`, `GOOGLE_OAUTH_CLIENT_IDS`, `APPLE_OAUTH_CLIENT_IDS` - nem qualquer `.env` que nao seja o `.env.example`. O `README.md` (secoes "Render e Neon" e "Atualizacao deste guia") e o `AUTH_PROVIDERS.md` mostram onde cada um e configurado.
- Nunca crie novos arquivos Markdown no repositorio: atualize as secoes existentes do `README.md`.
- Nunca faca merge, deploy nem apague branch remota sem pedido explicito.



</invoke>
